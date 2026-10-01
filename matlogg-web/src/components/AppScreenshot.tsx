type Screen = "home" | "meals" | "search" | "overview";

export function AppScreenshot({ screen, label, priority = false }: {
  screen: Screen;
  label: string;
  priority?: boolean;
}) {
  return (
    <figure className="mx-auto w-full max-w-[300px]">
      <div className="overflow-hidden rounded-[2.5rem] border border-foreground/10 bg-cream shadow-device">
        <img
          src={`./screenshots/${screen}.png`}
          alt={`Skjermbilde fra MatLogg: ${label}. Vist med fiktive demodata.`}
          width={1206}
          height={2622}
          loading={priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : "auto"}
          className="block h-auto w-full"
        />
      </div>
      <figcaption className="mt-4 text-center text-xs leading-relaxed text-muted-foreground">
        {label} · ekte appskjermbilde med demodata
      </figcaption>
    </figure>
  );
}
