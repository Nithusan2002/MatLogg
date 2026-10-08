import { useState } from "react";
import { AppScreenshot } from "./AppScreenshot";

const STEPS = [
  { tab: "Søk", screen: "flow-search", title: "Søk eller skann", text: "Finn matvaren du vil loggføre. Her søker vi etter havregryn.", label: "Søk – havregryn i appens matsøk" },
  { tab: "Mengde", screen: "flow-amount", title: "Velg mengde", text: "Kontroller matvaren, mengden og måltidet før du legger den til.", label: "Mengde – produktvisning før logging" },
  { tab: "Logg", screen: "flow-log", title: "Se maten i loggen", text: "Registreringen vises i måltidsloggen etter at den er lagret på enheten.", label: "Logg – måltidet etter registrering" },
] as const;

export function DemoSection() {
  const [selected, setSelected] = useState(0);
  const step = STEPS[selected] ?? STEPS[0];
  return (
    <section id="slik" className="mx-auto max-w-6xl px-5 py-24">
      <div className="grid items-center gap-14 lg:grid-cols-2">
        <div>
          <p className="eyebrow">Slik fungerer det</p>
          <h2 className="mt-3 text-4xl font-bold tracking-tight sm:text-5xl">Fra matvare til matlogg</h2>
          <p className="mt-4 max-w-md text-muted-foreground">Finn maten. Velg mengden. Ferdig. Velg et steg for å se ekte appbilder med fiktive demodata.</p>
          <ol className="mt-10 space-y-3">
            {STEPS.map((item, index) => (
              <li key={item.tab}>
                <button onClick={() => setSelected(index)} aria-pressed={selected === index} aria-controls="flow-screenshot"
                  className={`flex w-full gap-4 rounded-2xl border p-5 text-left transition ${selected === index ? "border-primary/40 bg-card shadow-soft" : "border-transparent hover:bg-card/60"}`}>
                  <span className={`grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-bold ${selected === index ? "bg-primary text-primary-foreground" : "bg-muted"}`}>{index + 1}</span>
                  <span><span className="block font-semibold">{item.title}</span><span className="text-sm text-muted-foreground">{item.text}</span></span>
                </button>
              </li>
            ))}
          </ol>
        </div>
        <div>
          <div role="group" aria-label="Steg i matlogging" className="mx-auto mb-6 flex w-fit rounded-full border bg-card p-1">
            {STEPS.map((item, index) => (
              <button key={item.tab} aria-pressed={selected === index} aria-controls="flow-screenshot" onClick={() => setSelected(index)}
                className={`min-h-11 rounded-full px-5 text-sm font-semibold ${selected === index ? "bg-foreground text-background" : "text-muted-foreground"}`}>{item.tab}</button>
            ))}
          </div>
          <div id="flow-screenshot" className="demo-stage" aria-live="polite" aria-atomic="true">
            <div key={step.screen} className="demo-frame">
            <AppScreenshot screen={step.screen} label={step.label} />
            </div>
          </div>
          <p className="mt-5 text-center text-sm text-muted-foreground">{selected + 1} / 3 · {step.title}</p>
        </div>
      </div>
    </section>
  );
}
