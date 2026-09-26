import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SyncEventsRequestDto, SyncEventDto } from './dto';
import { z } from 'zod';
import {
  decodeBase64Payload, favoritePayloadSchema, goalPayloadSchema, logPayloadSchema,
  MAX_SYNC_EVENTS, MAX_SYNC_PAYLOAD_BYTES, productPayloadSchema,
  savedMealPayloadSchema, SYNC_SCHEMA_VERSION, syncEventTypes, weightPayloadSchema,
} from './sync.contract';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(private readonly prisma: PrismaService) {}

  async syncEvents(userId: string, body: SyncEventsRequestDto) {
    const acked: string[] = [];
    const rejected: { eventId: string; code: string; message: string }[] = [];

    if (body.events.length > MAX_SYNC_EVENTS) {
      return {
        ackedEventIds: [],
        rejected: body.events.map((event) => ({
          eventId: event.eventId,
          code: 'VALIDATION_ERROR',
          message: `Maks ${MAX_SYNC_EVENTS} events per batch`,
        })),
      };
    }

    for (const event of body.events) {
      const result = await this.handleEvent(userId, body.deviceId, event).catch((error) => ({
        status: 'rejected' as const,
        eventId: event.eventId,
        code: 'SERVER_ERROR',
        message: error instanceof Error ? error.message : 'Server error',
      }));

      if (result.status === 'acked') {
        acked.push(result.eventId);
      } else {
        rejected.push({
          eventId: result.eventId,
          code: result.code,
          message: result.message,
        });
      }
    }

    return { ackedEventIds: acked, rejected };
  }

  private async handleEvent(userId: string, deviceId: string, event: SyncEventDto) {
    if (event.schemaVersion !== SYNC_SCHEMA_VERSION) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'UNSUPPORTED_SCHEMA', message: 'Ukjent schema-versjon' };
    }
    if (!syncEventTypes.has(event.type)) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'UNSUPPORTED_TYPE', message: 'Ukjent type' };
    }

    const payloadBuffer = decodeBase64Payload(event.payload);
    if (!payloadBuffer) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Ugyldig base64' };
    }

    if (payloadBuffer.byteLength > MAX_SYNC_PAYLOAD_BYTES) {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Payload for stor' };
    }

    let payloadJson: any;
    try {
      payloadJson = JSON.parse(payloadBuffer.toString('utf8'));
    } catch {
      return { status: 'rejected' as const, eventId: event.eventId, code: 'VALIDATION_ERROR', message: 'Ugyldig JSON' };
    }

    const existing = await this.prisma.eventInbox.findUnique({
      where: { eventId: event.eventId },
    });
    if (existing) {
      return existing.userId === userId
        ? { status: 'acked' as const, eventId: event.eventId }
        : { status: 'rejected' as const, eventId: event.eventId, code: 'FORBIDDEN', message: 'Hendelsen tilhører en annen bruker' };
    }

    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.eventInbox.create({
          data: {
            eventId: event.eventId,
            userId,
            deviceId,
            type: event.type,
            createdAt: new Date(event.createdAt),
            schemaVersion: event.schemaVersion,
            payloadJson,
          },
        });

        await this.applyEvent(tx, userId, event, payloadJson);
      });
    } catch (error) {
      if (error instanceof ValidationError) {
        return {
          status: 'rejected' as const,
          eventId: event.eventId,
          code: 'VALIDATION_ERROR',
          message: error.message,
        };
      }
      if (error instanceof AuthorizationError) {
        return {
          status: 'rejected' as const,
          eventId: event.eventId,
          code: 'FORBIDDEN',
          message: error.message,
        };
      }
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const racedEvent = await this.prisma.eventInbox.findUnique({ where: { eventId: event.eventId } });
        if (racedEvent) {
          return racedEvent.userId === userId
            ? { status: 'acked' as const, eventId: event.eventId }
            : { status: 'rejected' as const, eventId: event.eventId, code: 'FORBIDDEN', message: 'Hendelsen tilhører en annen bruker' };
        }
      }
      this.logger.error(`Sync event ${event.eventId} failed`, error instanceof Error ? error.stack : undefined);
      return {
        status: 'rejected' as const,
        eventId: event.eventId,
        code: 'SERVER_ERROR',
        message: 'Midlertidig serverfeil',
      };
    }

    return { status: 'acked' as const, eventId: event.eventId };
  }

  private async applyEvent(tx: Prisma.TransactionClient, userId: string, event: SyncEventDto, payloadJson: any) {
    switch (event.type) {
      case 'log.create':
      case 'log.update':
      case 'log.upsert': {
        const parsed = logPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig logg-payload');
        }
        const log = parsed.data;
        const existing = await tx.log.findUnique({ where: { id: log.id } });
        if (existing && existing.userId !== userId) {
          throw new AuthorizationError('Loggen tilhører en annen bruker');
        }
        const data = {
            date: new Date(log.date),
            meal: log.meal,
            grams: log.grams,
            unit: log.unit,
            kcal: Math.round(log.kcal),
            protein: log.protein,
            carbs: log.carbs,
            fat: log.fat,
            productRef: log.productRef ?? null,
        };
        if (existing) {
          await tx.log.update({ where: { id: log.id }, data });
        } else {
          await tx.log.create({ data: {
            id: log.id,
            userId,
            ...data,
          } });
        }
        break;
      }
      case 'log.delete': {
        const parsed = z.object({ id: z.string() }).safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig logg-delete payload');
        }
        await tx.log.deleteMany({ where: { id: parsed.data.id, userId } });
        break;
      }
      case 'goal.set': {
        const parsed = goalPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig mål-payload');
        }
        await tx.goal.upsert({
          where: { userId },
          update: {
            kcalTarget: Math.round(parsed.data.kcalTarget),
            proteinTarget: parsed.data.proteinTarget,
            carbTarget: parsed.data.carbTarget,
            fatTarget: parsed.data.fatTarget,
          },
          create: {
            userId,
            kcalTarget: Math.round(parsed.data.kcalTarget),
            proteinTarget: parsed.data.proteinTarget,
            carbTarget: parsed.data.carbTarget,
            fatTarget: parsed.data.fatTarget,
          },
        });
        break;
      }
      case 'favorite.add': {
        const parsed = favoritePayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig favoritt-payload');
        }
        await tx.favorite.upsert({
          where: { userId_productId: { userId, productId: parsed.data.productId } },
          update: {},
          create: { userId, productId: parsed.data.productId },
        });
        break;
      }
      case 'favorite.remove': {
        const parsed = favoritePayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig favoritt-payload');
        }
        await tx.favorite.deleteMany({
          where: { userId, productId: parsed.data.productId },
        });
        break;
      }
      case 'weight.add':
      case 'weight.upsert': {
        const parsed = weightPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig vekt-payload');
        }
        const weight = parsed.data;
        const existing = await tx.weight.findUnique({ where: { id: weight.id } });
        if (existing && existing.userId !== userId) {
          throw new AuthorizationError('Vektregistreringen tilhører en annen bruker');
        }
        const data = {
            userId,
            date: new Date(weight.date),
            weightKg: weight.weightKg,
        };
        if (existing) await tx.weight.update({ where: { id: weight.id }, data });
        else await tx.weight.create({ data: { id: weight.id, ...data } });
        break;
      }
      case 'weight.delete': {
        const parsed = z.object({ id: z.string().uuid() }).safeParse(payloadJson);
        if (!parsed.success) throw new ValidationError('Ugyldig vekt-delete payload');
        await tx.weight.deleteMany({ where: { id: parsed.data.id, userId } });
        break;
      }
      case 'product.upsert': {
        const parsed = productPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig produkt-payload');
        }
        const product = parsed.data;
        const existing = await tx.product.findUnique({ where: { id: product.id } });
        if (existing && existing.userId !== userId) {
          throw new AuthorizationError('Produktet kan ikke endres av denne brukeren');
        }
        const data = {
            name: parsed.data.name,
            brand: parsed.data.brand ?? null,
            barcode: parsed.data.barcode ?? null,
            nutrientsPer100g: parsed.data.nutrientsPer100g,
            imageUrl: parsed.data.imageUrl ?? null,
            source: parsed.data.source,
        };
        if (existing) {
          await tx.product.update({ where: { id: product.id }, data });
        } else {
          await tx.product.create({ data: {
            id: parsed.data.id,
            userId,
            ...data,
          } });
        }
        break;
      }
      case 'saved_meal.upsert': {
        const parsed = savedMealPayloadSchema.safeParse(payloadJson);
        if (!parsed.success) {
          throw new ValidationError('Ugyldig lagret-måltid-payload');
        }
        const meal = parsed.data;
        const existing = await tx.savedMeal.findUnique({ where: { id: meal.id } });
        if (existing && existing.userId !== userId) {
          throw new AuthorizationError('Det lagrede måltidet tilhører en annen bruker');
        }
        const data = {
          name: meal.name,
          suggestedMealType: meal.suggestedMealType ?? null,
          updatedAt: new Date(meal.updatedAt),
        };
        if (existing) {
          await tx.savedMeal.update({ where: { id: meal.id }, data });
          await tx.savedMealItem.deleteMany({ where: { savedMealId: meal.id } });
        } else {
          await tx.savedMeal.create({ data: { id: meal.id, userId, ...data } });
        }
        await tx.savedMealItem.createMany({
          data: meal.items.map((item) => ({
            id: item.id,
            savedMealId: meal.id,
            productId: item.productId,
            productName: item.productName,
            grams: item.amountG,
            unit: item.amountUnit,
            kcal: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            nutritionSource: item.nutritionSource,
            sortIndex: item.sortIndex,
          })),
        });
        break;
      }
      case 'saved_meal.delete': {
        const parsed = z.object({ id: z.string().uuid() }).safeParse(payloadJson);
        if (!parsed.success) throw new ValidationError('Ugyldig lagret-måltid-delete payload');
        const existing = await tx.savedMeal.findUnique({ where: { id: parsed.data.id } });
        if (existing && existing.userId !== userId) {
          throw new AuthorizationError('Det lagrede måltidet tilhører en annen bruker');
        }
        await tx.savedMeal.deleteMany({ where: { id: parsed.data.id, userId } });
        break;
      }
      default:
        throw new ValidationError('Ukjent type');
    }
  }
}

class ValidationError extends Error {}
class AuthorizationError extends Error {}
