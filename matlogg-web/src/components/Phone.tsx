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

export function Macro({ label, g, color, pct }: { label: string; g: number; color: string; pct: number }) {
  return (
    <div className="min-w-0">
      <div className="text-[10px] leading-tight"><span className="block text-[9px] tracking-tight text-muted-foreground">{label}</span><span className="font-semibold">{g} g</span></div>
      <div className="mt-1 h-1.5 rounded-full bg-muted"><div className={`h-full rounded-full ${color}`} style={{ width: `${pct}%` }} /></div>
    </div>
  );
}

export function HomeScreen() {
  return (
    <div className="px-4 pt-4">
      <p className="text-[11px] text-muted-foreground">Torsdag 1. oktober</p>
      <h3 className="text-xl font-bold">I dag</h3>
      <div className="mt-3 rounded-2xl border bg-card p-4">
        <div className="flex items-baseline justify-between">
          <div><span className="text-3xl font-bold">1 240</span> <span className="text-xs text-muted-foreground">kcal</span></div>
          <span className="rounded-full bg-accent-soft px-2 py-0.5 text-[9px] font-semibold text-accent">Demo</span>
        </div>
        <div className="mt-3 grid grid-cols-3 gap-2">
          <Macro label="Protein" g={62} color="bg-protein" pct={60} />
          <Macro label="Karbohydrater" g={140} color="bg-carb" pct={55} />
          <Macro label="Fett" g={41} color="bg-fat" pct={48} />
        </div>
      </div>
      {[
        { m: "Frokost", k: 420, items: "Havregryn, melk, blåbær" },
        { m: "Lunsj", k: 610, items: "Grovbrød, egg, agurk" },
      ].map((x) => (
        <div key={x.m} className="mt-3 rounded-2xl border bg-card p-3.5">
          <div className="flex justify-between text-sm font-semibold"><span>{x.m}</span><span>{x.k} kcal</span></div>
          <p className="mt-1 text-[11px] text-muted-foreground">{x.items}</p>
        </div>
      ))}
      <p className="mt-3 text-center text-[9px] text-muted-foreground">Illustrasjon – ikke verifiserte næringsverdier</p>
      <TabBar />
    </div>
  );
}

