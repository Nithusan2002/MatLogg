import { useEffect, useRef, useState, type ReactNode } from "react";
import { AppScreenshot } from "./components/AppScreenshot";
import { DemoSection } from "./components/DemoApp";


function Logo() {
  return (
    <span className="flex items-center gap-2 font-bold">
      <img src="./matlogg-logo.png" alt="" width="40" height="40" className="h-10 w-10 rounded-xl" />
      MatLogg
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
  ["Er MatLogg tilgjengelig?", "MatLogg er under utvikling. Betatilgang og lansering er ikke åpnet ennå."],
  ["Må jeg ha konto?", "Nei. MatLogg er laget for å kunne brukes lokalt på iPhonen uten konto."],
  ["Fungerer det uten nett?", "Ja, lokal logging og lagrede matvarer fungerer uten nett. Oppslag av nye produkter kan kreve internett."],
  ["Må jeg sette mål?", "Nei. Mål er helt valgfrie. Du kan bruke MatLogg bare for oversikt."],
  ["Hvilke enheter støttes?", "MatLogg utformes for iPhone med iOS 17 eller nyere."],
];

function Faq() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <section id="faq" className="mx-auto max-w-3xl px-5 py-24">
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
            <h1 className="mt-6 text-5xl font-bold leading-[1.04] tracking-tight sm:text-6xl">Matlogging som passer <span className="hero-highlight">hverdagen din.</span></h1>
            <p className="mt-6 max-w-lg text-lg text-muted-foreground">Søk etter mat, skann strekkoder og få oversikt over dagen. Enkelt, rolig og på norsk.</p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <a href="#slik" className="btn-primary">Se MatLogg i bruk <span aria-hidden>→</span></a>
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
              <p>Det du spiser ofte, trenger du ikke å legge inn fra bunnen hver gang. Lagre måltidet, juster mengdene og loggfør det på nytt.</p>
              <a href="#slik" className="btn-ghost mt-6">Se hvordan du logger <span aria-hidden>↗</span></a>
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
              <div><p className="eyebrow">Fra favoritt til matlogg</p><h3>Samme måltid.<br />En ny dag.</h3><p>Lagrede måltider ligger klare i appen. Du velger selv hva og hvor mye du vil loggføre.</p><p className="meal-image-note">Måltidsbildene er AI-genererte illustrasjoner. Appbildet viser fiktive demodata.</p></div>
              <AppScreenshot screen="meals" label="Lagrede måltider – klare til gjenbruk" />
            </div>
          </section>
          <Feature flip eyebrow="Oversikt" title="Oversikt på dine premisser" visual={
            <AppScreenshot screen="overview" label="Utvikling – historikk og næringsoversikt" />
          }>
            <p>Se dagens energi og makronæringsstoffer, og følg oversikten gjennom uken.</p>
            <p>Mål er valgfrie. Ingen røde tall, ingen «bra» eller «dårlig» mat – bare tydelig oversikt.</p>
          </Feature>
          <Feature eyebrow="Lokalt" title="På iPhonen. Også uten nett." visual={
            <AppScreenshot screen="diary" label="Dagbok – dagens måltider lagret på iPhonen" />
          }>
            <p>Loggen og lagrede matvarer ligger på iPhonen din, så logging av det du allerede har fungerer uten nett.</p>
            <p>Oppslag av nye produkter kan kreve internett. Synkronisering mellom enheter og sikkerhetskopi er ikke en del av MVP-en.</p>
            <p className="text-sm">Norske råvarer fra Matvaretabellen og produktoppslag fra Open Food Facts.</p>
          </Feature>
        </section>

        <Faq />

        <section className="mx-auto max-w-6xl px-5 pb-24">
          <div className="rounded-[2.5rem] border border-primary/20 bg-primary-soft px-6 py-16 text-center">
            <h2 className="text-4xl font-bold tracking-tight">Litt mindre styr. Litt mer oversikt.</h2>
            <p className="mx-auto mt-4 max-w-md text-muted-foreground">MatLogg er under utvikling. Utforsk hvordan appen fungerer mens vi gjør den klar for lansering.</p>
            <a href="#slik" className="btn-primary mt-8">Se demoen <span aria-hidden>→</span></a>
          </div>
        </section>
      </main>

      <footer className="border-t">
        <div className="mx-auto flex max-w-6xl flex-col gap-4 px-5 py-8 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3"><Logo /><span className="rounded-full border px-2.5 py-0.5 text-xs text-muted-foreground">Prototype</span></div>
          <div className="flex flex-wrap gap-2">
            <a href="./personvern.html" className="flex min-h-11 items-center px-3 text-sm text-muted-foreground hover:text-foreground">Personvern</a>
            <a href="./personvern.html#bildekilder" className="flex min-h-11 items-center px-3 text-sm text-muted-foreground hover:text-foreground">Bildekilder</a>
            <button onClick={() => setDlg("contact")} className="min-h-11 px-3 text-sm text-muted-foreground hover:text-foreground">Kontakt</button>
          </div>
        </div>
      </footer>

      <Modal open={dlg === "contact"} onClose={close} title="Kontakt">
        <p>MatLogg drives av Nithusan Krishnasamymudali.</p>
        <p><a className="underline" href="mailto:nithusank.2002@gmail.com">nithusank.2002@gmail.com</a></p>
        <p className="text-sm">Unngå å sende matlogger, vekt eller andre helseopplysninger på vanlig e-post.</p>
      </Modal>
    </div>
  );
}
