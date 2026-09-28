import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { runtimeConfig } from './config/runtime.config';

async function bootstrap() {
  const runtime = runtimeConfig();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bodyParser: false });
  app.enableShutdownHooks();
  app.useBodyParser('json', { limit: '5mb' });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.use(helmet({ contentSecurityPolicy: runtime.isProduction }));

  if (runtime.trustProxyHops > 0) {
    app.set('trust proxy', runtime.trustProxyHops);
  }
  app.enableCors({ origin: runtime.corsAllowedOrigins.length > 0 ? runtime.corsAllowedOrigins : false });

  if (runtime.swaggerEnabled) {
    const config = new DocumentBuilder()
      .setTitle('MatLogg API')
      .setDescription('MatLogg MVP backend')
      .setVersion('0.1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document);
  }

  await app.listen(runtime.port, '0.0.0.0');
}

bootstrap().catch((error) => {
  console.error('MatLogg API failed to start', error instanceof Error ? error.message : 'unknown error');
  process.exitCode = 1;
});
