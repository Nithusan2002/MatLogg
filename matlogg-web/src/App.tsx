import { useEffect, useRef, useState, type ReactNode } from "react";
import { AppScreenshot } from "./components/AppScreenshot";
import { DemoSection } from "./components/DemoApp";


function Logo() {
  return (
    <span className="flex items-center gap-2 font-bold">
      <img src="./matlogg-logo.png" alt="" width="40" height="40" className="h-10 w-10 rounded-xl" />
      Spor Mat
    </span>
  );
}

function Modal({ open, onClose, title, children }: { open: boolean; onClose: () => void; title: string; children: ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current; if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog ref={ref} onClose={onClose}
      aria-labelledby={`dlg-${title}`} className="m-auto w-[min(92vw,440px)] rounded-3xl border bg-card p-0 text-foreground shadow-device">
      <div className="p-7">
        <h2 id={`dlg-${title}`} className="text-xl font-bold">{title}</h2>
        <div className="mt-3 space-y-2 text-muted-foreground">{children}</div>
        <button onClick={onClose} className="btn-primary mt-6 w-full" autoFocus>Lukk</button>
      </div>
    </dialog>
  );
}

const FAQ = [
  ["Er Spor Mat tilgjengelig?", "Spor Mat er under utvikling. Betatilgang og lansering er ikke åpnet ennå. Bildedemoen viser hvordan appen fungerer i dag."],
  ["Må jeg ha konto?", "Nei. Du kan logge mat på iPhonen uten å opprette konto. Innlogging er valgfritt og gir foreløpig ikke skybackup."],
  ["Hvor lagres dataene mine?", "Matloggen lagres lokalt på iPhonen din. Spor Mat tilbyr foreløpig ikke skybackup eller synk mellom enheter. Du kan eksportere en JSON-kopi, men den kan ikke importeres tilbake i appen. Data kan gå tapt hvis du sletter appen eller mister telefonen."],
];

function Faq() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <section id="faq" className="mx-auto max-w-3xl px-5 py-16 sm:py-20">
      <p className="eyebrow">Spørsmål</p>
      <h2 className="mt-3 text-4xl font-bold tracking-tight">Ofte stilte spørsmål</h2>
      <div className="mt-10 divide-y rounded-3xl border bg-card">
        {FAQ.map(([q, a], i) => (
          <div key={q}>
            <h3>
              <button id={`fq-${i}`} aria-expanded={open === i} aria-controls={`fa-${i}`} onClick={() => setOpen(open === i ? null : i)}
                className="flex min-h-16 w-full items-center justify-between gap-4 px-6 text-left font-semibold">
                {q}<span className={`text-xl text-primary transition ${open === i ? "rotate-45" : ""}`} aria-hidden>+</span>
              </button>
            </h3>
            <div id={`fa-${i}`} role="region" aria-labelledby={`fq-${i}`} hidden={open !== i} className="px-6 pb-6 text-muted-foreground">{a}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

function Feature({ eyebrow, title, children, visual, flip }: { eyebrow: string; title: string; children: ReactNode; visual: ReactNode; flip?: boolean }) {
  return (
    <div className="feature-panel grid items-center gap-12 rounded-[2.5rem] border p-7 sm:p-12 lg:grid-cols-2">
      <div className={flip ? "lg:order-2" : ""}>
        <p className="eyebrow">{eyebrow}</p>
        <h3 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">{title}</h3>
        <div className="mt-4 max-w-md space-y-3 text-muted-foreground">{children}</div>
      </div>
      <div className={flip ? "lg:order-1" : ""}>{visual}</div>
    </div>
  );
}

export default function App() {
  const [menu, setMenu] = useState(false);
  const [dlg, setDlg] = useState<null | "contact">(null);
  const close = () => setDlg(null);
  const links = [["#slik", "Slik fungerer det"], ["#funksjoner", "Funksjoner"], ["#faq", "Spørsmål"]];

  return (
    <div className="overflow-x-hidden">
      <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-card focus:p-3">Hopp til innhold</a>
      <header className="sticky top-0 z-40 border-b bg-background/85 backdrop-blur">
        <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5" aria-label="Hovedmeny">
          <a href="#top" className="flex min-h-11 items-center"><Logo /></a>
          <div className="hidden items-center gap-8 md:flex">
            {links.map(([h, l]) => <a key={h} href={h} className="text-sm text-muted-foreground hover:text-foreground">{l}</a>)}
            <a href="#slik" className="btn-primary !min-h-11 text-sm">Se demoen <span aria-hidden>↗</span></a>
          </div>
          <button className="grid h-11 w-11 place-items-center rounded-full border md:hidden" aria-expanded={menu} aria-controls="mobilmeny" aria-label={menu ? "Lukk meny" : "Åpne meny"} onClick={() => setMenu(!menu)}>
            <span aria-hidden className="text-lg">{menu ? "✕" : "☰"}</span>
          </button>
        </nav>
        {menu && (
          <div id="mobilmeny" className="border-t bg-background px-5 pb-5 md:hidden">
            {links.map(([h, l]) => <a key={h} href={h} onClick={() => setMenu(false)} className="flex min-h-12 items-center border-b">{l}</a>)}
            <a href="#slik" onClick={() => setMenu(false)} className="btn-primary mt-4 w-full">Se demoen</a>
          </div>
        )}
      </header>

      <main id="main">
        <section id="top" className="hero-section mx-auto grid max-w-6xl items-center gap-14 px-5 pb-16 pt-14 lg:grid-cols-[1.1fr_1fr] lg:pt-24">
          <div>
            <span className="inline-flex items-center gap-2 rounded-full border bg-card px-3 py-1.5 text-xs font-medium">
              <span className="h-1.5 w-1.5 rounded-full bg-accent" aria-hidden />Norsk matlogging · Under utvikling
            </span>
            <aside className="mt-4 text-sm text-muted-foreground" aria-label="Nytt navn">
              <p><strong className="font-semibold text-foreground">MatLogg heter nå Spor Mat.</strong> Samme app, nytt navn.</p>
            </aside>
            <h1 className="mt-6 text-5xl font-bold leading-[1.04] tracking-tight sm:text-6xl">Logg maten.<br /><span className="hero-highlight">Uten å lage konto.</span></h1>
            <p className="mt-6 max-w-lg text-lg text-muted-foreground">Norske råvarer, strekkodesøk og en matlogg som lagres på iPhonen din. Få oversikt over maten, med eller uten mål.</p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <a href="#slik" className="btn-primary">Se demoen <span aria-hidden>→</span></a>
              <a href="#funksjoner" className="btn-ghost">Utforsk appen</a>
            </div>
          </div>
          <div className="hero-stage">
            <div className="hero-orbit" aria-hidden="true" />
            <div className="hero-phone"><AppScreenshot screen="home" label="Dagen din, samlet på ett sted" priority /></div>
            <div className="hero-note hero-note-top"><span aria-hidden="true">✦</span><div><strong>Din dag. Din oversikt.</strong><span>Mål er helt valgfrie.</span></div></div>
            <div className="hero-note hero-note-bottom"><span aria-hidden="true">↗</span><div><strong>Enklere neste gang</strong><span>Lagre måltider du bruker ofte.</span></div></div>
          </div>
        </section>

        <ul className="mx-auto grid max-w-6xl gap-4 px-5 sm:grid-cols-3">
          {[["01", "Uten konto", "Start med maten. Registrering er valgfritt."], ["02", "Også uten nett", "Logg med matvarene som er lagret på iPhonen."], ["03", "På dine premisser", "Få oversikt, med eller uten mål."]].map(([n, t, d]) => (
            <li key={t} className="benefit-card rounded-3xl border bg-card p-6"><span className="eyebrow">{n}</span><p className="mt-5 text-xl font-semibold">{t}</p><p className="text-sm text-muted-foreground">{d}</p></li>
          ))}
        </ul>

        <DemoSection />

        <section id="funksjoner" className="mx-auto max-w-6xl space-y-8 px-5">
          <section className="meal-story" aria-labelledby="meal-story-title">
            <div className="meal-story-heading">
              <p className="eyebrow">Dine gjengangere</p>
              <h2 id="meal-story-title">Favorittfrokosten din.<br /><span>Klar igjen i morgen.</span></h2>
              <p>Lagre et måltid fra dagboken og loggfør det igjen når det passer. Velg dato og måltid før du lagrer, og angre rett etterpå hvis du vil.</p>
            </div>
            <div className="meal-story-pictures">
              <figure className="meal-photo meal-photo-breakfast">
                <img src="./meals/yoghurt.jpg" alt="Illustrasjon av yoghurt med havre, blåbær og banan" width="640" height="640" loading="lazy" />
                <figcaption><span>01 / Frokost</span><strong>Yoghurt med havre og bær</strong></figcaption>
              </figure>
              <figure className="meal-photo meal-photo-dinner">
                <img src="./meals/salmon.jpg" alt="Illustrasjon av laks med poteter og brokkoli" width="640" height="640" loading="lazy" />
                <figcaption><span>02 / Middag</span><strong>Laks med poteter</strong></figcaption>
              </figure>
            </div>
            <div className="meal-story-app">
              <AppScreenshot screen="meals" label="Lagrede måltider – klare til gjenbruk" />
            </div>
            <p className="meal-image-note">Måltidsbildene er AI-genererte illustrasjoner. Appbildet viser fiktive demodata.</p>
          </section>
          <Feature flip eyebrow="Utvikling" title="Oversikt på dine premisser" visual={
            <AppScreenshot screen="overview" label="Utvikling – mat, skritt, vekt og treningsøkter" />
          }>
            <p>Samle mat, skritt, vekt og treningsøkter i én oversikt. Velg selv hvilke kort du vil se, og bla mellom dag, uke og måned.</p>
            <p>Skritt, vekt og treningsøkter fra Apple Helse vises når du velger å koble dem til. Du kan også registrere vekt manuelt. Bildet viser fiktive demodata.</p>
          </Feature>
          <div className="grid gap-6 sm:grid-cols-2">
            {[
              ["En dagbok du kan endre", "Rediger matvarer og mengder, flytt dem mellom måltider eller velg flere registreringer samlet."],
              ["Norske råvarer og kjente produkter", "Søk i Matvaretabellen og slå opp merkevarer fra Open Food Facts. Matvarene viser kilden og næringsgrunnlaget."],
            ].map(([title, text]) => (
              <article key={title} className="benefit-card rounded-3xl border bg-card p-7">
                <h3 className="text-xl font-semibold">{title}</h3>
                <p className="mt-3 text-muted-foreground">{text}</p>
              </article>
            ))}
          </div>
          <Feature eyebrow="Lokalt" title="På iPhonen. Også uten nett." visual={
            <AppScreenshot screen="diary" label="Dagbok – dagens måltider lagret på iPhonen" />
          }>
            <p>Loggen og lagrede matvarer ligger på iPhonen din, så logging av det du allerede har fungerer uten nett.</p>
            <p>Oppslag av nye produkter kan kreve internett. Appen tilbyr ikke skybackup eller synk mellom enheter. Data kan gå tapt hvis du sletter appen eller mister telefonen.</p>
          </Feature>
        </section>

        <Faq />

        <section className="mx-auto max-w-6xl px-5 pb-24">
          <div className="rounded-[2.5rem] border border-primary/20 bg-primary-soft px-6 py-16 text-center">
            <h2 className="text-4xl font-bold tracking-tight">Se matloggingen i praksis.</h2>
            <p className="mx-auto mt-4 max-w-md text-muted-foreground">Bla gjennom søk, mengde og logg i bildedemoen. Spor Mat er fortsatt under utvikling.</p>
            <a href="#slik" className="btn-primary mt-8">Se demoen <span aria-hidden>→</span></a>
          </div>
        </section>
      </main>

      <footer className="border-t">
        <div className="mx-auto flex max-w-6xl flex-col gap-4 px-5 py-8 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3"><Logo /><span className="rounded-full border px-2.5 py-0.5 text-xs text-muted-foreground">Under utvikling</span></div>
          <div className="flex flex-wrap gap-2">
            <a href="./personvern.html" className="flex min-h-11 items-center px-3 text-sm text-muted-foreground hover:text-foreground">Personvern</a>
            <a href="./personvern.html#bildekilder" className="flex min-h-11 items-center px-3 text-sm text-muted-foreground hover:text-foreground">Bildekilder</a>
            <button onClick={() => setDlg("contact")} className="min-h-11 px-3 text-sm text-muted-foreground hover:text-foreground">Kontakt</button>
          </div>
        </div>
      </footer>

      <Modal open={dlg === "contact"} onClose={close} title="Kontakt">
        <p>Spor Mat drives av Nithusan Krishnasamymudali.</p>
        <p><a className="underline" href="mailto:nithusank.2002@gmail.com">nithusank.2002@gmail.com</a></p>
        <p className="text-sm">Unngå å sende matlogger, vekt eller andre helseopplysninger på vanlig e-post.</p>
      </Modal>
    </div>
  );
}
