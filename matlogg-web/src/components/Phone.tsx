import type { ReactNode } from "react";

export function Phone({ children, label = "Illustrativ appvisning" }: { children: ReactNode; label?: string }) {
  return (
    <figure className="relative mx-auto w-full max-w-[300px]">
      <div className="rounded-[3rem] bg-device p-[10px] shadow-device">
        <div className="relative h-[600px] overflow-hidden rounded-[2.4rem] bg-cream">
          <div className="absolute left-1/2 top-2 z-10 h-7 w-24 -translate-x-1/2 rounded-full bg-device" aria-hidden />
          <div className="flex justify-between px-7 pt-3 text-[11px] font-semibold" aria-hidden>
            <span>9:41</span><span>●●● ▮</span>
          </div>
          {children}
        </div>
      </div>
      <figcaption className="mt-4 text-center text-xs leading-relaxed text-muted-foreground">{label} · ikke et skjermbilde fra appen</figcaption>
    </figure>
  );
}

export function TabBar({ active = "Hjem" }: { active?: string }) {
  const items = ["Hjem", "Søk", "+", "Oversikt", "Profil"];
  return (
    <div className="absolute inset-x-0 bottom-0 flex items-end justify-around border-t bg-card px-2 pb-5 pt-2" aria-hidden>
      {items.map((i) =>
        i === "+" ? (
          <div key={i} className="-mt-6 flex flex-col items-center">
            <span className="grid h-12 w-12 place-items-center rounded-full bg-primary text-2xl text-primary-foreground shadow-soft">+</span>
            <span className="mt-0.5 text-[9px] text-muted-foreground">Loggfør</span>
          </div>
        ) : (
          <div key={i} className={`flex flex-col items-center gap-1 text-[9px] ${active === i ? "text-primary font-semibold" : "text-muted-foreground"}`}>
            <span className={`h-4 w-4 rounded-md border-2 ${active === i ? "border-primary" : "border-muted-foreground/50"}`} />
            {i}
          </div>
        ),
      )}
    </div>
  );
}

