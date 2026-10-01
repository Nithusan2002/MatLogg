import { useState } from "react";
import { Phone, TabBar } from "./Phone";

const PRODUCTS = [
  { name: "Havregryn", src: "Råvare", kcal: 370 },
  { name: "Lettmelk", src: "Råvare", kcal: 40 },
  { name: "Grovbrød", src: "Produkt", kcal: 240 },
  { name: "Egg, kokt", src: "Råvare", kcal: 150 },
  { name: "Yoghurt naturell", src: "Produkt", kcal: 65 },
  { name: "Banan", src: "Råvare", kcal: 90 },
];
type Tab = "Søk" | "Mengde" | "Logg";
const STEPS: { t: Tab; title: string; text: string }[] = [
  { t: "Søk", title: "Søk eller skann", text: "Finn en råvare eller skann strekkoden på en pakke." },
  { t: "Mengde", title: "Velg mengde", text: "Juster gram eller porsjon. Tallene oppdateres med en gang." },
  { t: "Logg", title: "Lagre i dagens måltid", text: "Velg måltid og loggfør. Angre om du ombestemmer deg." },
];

export function DemoSection() {
  const [tab, setTab] = useState<Tab>("Søk");
  const [q, setQ] = useState("");
  const [sel, setSel] = useState({ name: "Havregryn", src: "Råvare", kcal: 370 });
  const [grams, setGrams] = useState(60);
  const [meal, setMeal] = useState("Frokost");
  const [logged, setLogged] = useState(false);
  const list = PRODUCTS.filter((p) => p.name.toLowerCase().includes(q.toLowerCase()));
  const kcal = Math.round((sel.kcal * grams) / 100);

  return (
    <section id="slik" className="mx-auto max-w-6xl px-5 py-24">
      <div className="grid items-center gap-14 lg:grid-cols-2">
        <div>
          <p className="eyebrow">Slik fungerer det</p>
          <h2 className="mt-3 text-4xl font-bold tracking-tight sm:text-5xl">Fra matvare til matlogg</h2>
          <p className="mt-4 max-w-md text-muted-foreground">Tre rolige steg. Prøv demoen – ingenting lagres, og ingenting sendes.</p>
          <ol className="mt-10 space-y-3">
            {STEPS.map((s, i) => (
              <li key={s.t}>
                <button
                  onClick={() => { setTab(s.t); setLogged(false); }}
                  className={`flex w-full gap-4 rounded-2xl border p-5 text-left transition ${tab === s.t ? "border-primary/40 bg-card shadow-soft" : "border-transparent hover:bg-card/60"}`}
                  aria-pressed={tab === s.t}
                >
                  <span className={`grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-bold ${tab === s.t ? "bg-primary text-primary-foreground" : "bg-muted"}`}>{i + 1}</span>
                  <span><span className="block font-semibold">{s.title}</span><span className="text-sm text-muted-foreground">{s.text}</span></span>
                </button>
              </li>
            ))}
          </ol>
        </div>

        <div>
          <div role="group" aria-label="Demo-steg" className="mx-auto mb-6 flex w-fit rounded-full border bg-card p-1">
            {(["Søk", "Mengde", "Logg"] as Tab[]).map((t) => (
              <button key={t} aria-pressed={tab === t} onClick={() => { setTab(t); setLogged(false); }}
                className={`min-h-11 rounded-full px-5 text-sm font-semibold ${tab === t ? "bg-foreground text-background" : "text-muted-foreground"}`}>{t}</button>
            ))}
          </div>
          <Phone label="Interaktiv demo">
            <div className="px-4 pt-4" >
              {tab === "Søk" && (
                <>
                  <h3 className="text-xl font-bold">Søk</h3>
                  <label className="sr-only" htmlFor="demo-q">Søk etter demomatvare</label>
                  <input id="demo-q" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Søk etter mat …"
                    className="mt-3 h-11 w-full rounded-xl border bg-card px-3 text-sm" />
                  <ul className="mt-3 space-y-2">
                    {list.map((p) => (
                      <li key={p.name}>
                        <button onClick={() => { setSel(p); setTab("Mengde"); }} className="flex min-h-11 w-full items-center justify-between rounded-xl border bg-card px-3 py-2 text-left text-sm">
                          <span><span className="font-medium">{p.name}</span><span className="block text-[10px] text-muted-foreground">{p.src} · demo</span></span>
                          <span className="text-xs text-muted-foreground">{p.kcal} kcal/100 g</span>
                        </button>
                      </li>
                    ))}
                    {list.length === 0 && <li className="text-center text-xs text-muted-foreground">Ingen treff i demoen</li>}
                  </ul>
                </>
              )}
              {tab === "Mengde" && (
                <>
                  <h3 className="text-xl font-bold">{sel.name}</h3>
                  <p className="text-[11px] text-muted-foreground">Demoverdier – ikke verifisert</p>
                  <div className="mt-6 rounded-2xl border bg-card p-5 text-center">
                    <p className="text-4xl font-bold">{grams} g</p>
                    <p className="text-sm text-muted-foreground">{kcal} kcal</p>
                    <div className="mt-4 flex justify-center gap-3">
                      <button aria-label="Mindre mengde" onClick={() => setGrams((g) => Math.max(10, g - 10))} className="h-11 w-11 rounded-full border text-xl">−</button>
                      <button aria-label="Større mengde" onClick={() => setGrams((g) => Math.min(500, g + 10))} className="h-11 w-11 rounded-full border text-xl">+</button>
                    </div>
                  </div>
                  <button onClick={() => setTab("Logg")} className="btn-primary mt-5 w-full">Neste</button>
                </>
              )}
              {tab === "Logg" && (
                <>
                  <h3 className="text-xl font-bold">Lagre i måltid</h3>
                  <p className="mt-1 text-sm text-muted-foreground">{sel.name} · {grams} g · {kcal} kcal</p>
                  <div className="mt-4 grid grid-cols-2 gap-2">
                    {["Frokost", "Lunsj", "Middag", "Mellommåltid"].map((m) => (
                      <button key={m} aria-pressed={meal === m} onClick={() => { setMeal(m); setLogged(false); }}
                        className={`min-h-11 rounded-xl border text-sm ${meal === m ? "border-primary bg-primary-soft font-semibold" : "bg-card"}`}>{m}</button>
                    ))}
                  </div>
                  {logged ? (
                    <div className="mt-5 rounded-2xl border border-protein/40 bg-card p-4 text-sm">
                      <p className="font-semibold">Lagt til i {meal.toLowerCase()} (demo)</p>
                      <p className="text-xs text-muted-foreground">Kun i denne visningen – ingenting er lagret.</p>
                      <button onClick={() => setLogged(false)} className="mt-2 min-h-11 font-semibold text-accent underline underline-offset-4">Angre</button>
                    </div>
                  ) : (
                    <button onClick={() => setLogged(true)} className="btn-primary mt-5 w-full">Loggfør</button>
                  )}
                </>
              )}
              <TabBar active={tab === "Søk" ? "Søk" : "Hjem"} />
            </div>
          </Phone>
        </div>
      </div>
    </section>
  );
}

