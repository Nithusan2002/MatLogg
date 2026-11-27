import { useState } from "react";
import { AppScreenshot } from "./AppScreenshot";

const STEPS = [
  { screen: "flow-search", title: "Finn maten", text: "Søk i Matvaretabellen og Open Food Facts, eller skann en strekkode. Her finner vi havregryn.", label: "Søk – havregryn i appens matsøk" },
  { screen: "flow-amount", title: "Velg mengde", text: "Kontroller mengde, enhet, måltid og dato før du lagrer.", label: "Mengde – produktvisning før logging" },
  { screen: "flow-log", title: "Se måltidet", text: "Du får en bekreftelse når maten er lagret på enheten. Registreringen ligger nå i dagsoversikten.", label: "Hjem – måltidet etter registrering" },
] as const;

export function DemoSection() {
  const [selected, setSelected] = useState(0);
  const step = STEPS[selected];
  return (
    <section id="slik" className="mx-auto max-w-6xl px-5 py-16 sm:py-20" aria-labelledby="demo-title">
      <div className="grid items-start gap-8 lg:grid-cols-2">
        <div className="lg:pt-8">
          <p className="eyebrow">Slik fungerer det</p>
          <h2 id="demo-title" className="mt-3 text-4xl font-bold tracking-tight sm:text-5xl">Fra matvare til matlogg</h2>
          <p className="mt-4 max-w-md text-muted-foreground">Følg én logging i tre steg. Bildene er fra appen og viser fiktive demodata.</p>
          <ol aria-label="Velg steg i matloggingen" className="mt-6 space-y-2">
            {STEPS.map((item, index) => (
              <li key={item.screen}>
                <button type="button" onClick={() => setSelected(index)} aria-pressed={selected === index} aria-controls="flow-screenshot"
                  className={`flex min-h-11 w-full gap-4 rounded-2xl border p-4 text-left transition ${selected === index ? "border-primary/40 bg-card shadow-soft" : "border-transparent hover:bg-card/60"}`}>
                  <span className={`grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-bold ${selected === index ? "bg-primary text-primary-foreground" : "bg-muted"}`}>{index + 1}</span>
                  <span><span className="block font-semibold">{item.title}</span><span className="text-sm text-muted-foreground">{item.text}</span></span>
                </button>
              </li>
            ))}
          </ol>
        </div>
        <div>
          <div id="flow-screenshot" className="demo-stage">
            <AppScreenshot screen={step.screen} label={step.label} />
          </div>
          <p role="status" aria-live="polite" aria-atomic="true" className="my-4 text-center text-sm text-muted-foreground">{selected + 1} av 3 · {step.title}</p>
          <div className="demo-controls mx-auto flex max-w-sm items-center justify-between gap-3 rounded-2xl border bg-card p-2" role="group" aria-label="Bla gjennom appbildene">
            <button type="button" aria-disabled={selected === 0} onClick={() => setSelected(current => Math.max(0, current - 1))} aria-controls="flow-screenshot" className="min-h-11 rounded-xl px-4 text-sm font-semibold aria-disabled:opacity-40">← Forrige</button>
            <span aria-hidden="true" className="text-sm tabular-nums">{selected + 1} / 3</span>
            <button type="button" aria-disabled={selected === STEPS.length - 1} onClick={() => setSelected(current => Math.min(STEPS.length - 1, current + 1))} aria-controls="flow-screenshot" className="min-h-11 rounded-xl px-4 text-sm font-semibold aria-disabled:opacity-40">Neste →</button>
          </div>
        </div>
      </div>
    </section>
  );
}
