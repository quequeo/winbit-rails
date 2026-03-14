export const PlaceholderPage = ({ title }: { title: string }) => {
  return (
    <div className="space-y-2">
      <h1 className="text-3xl font-bold text-t-primary">{title}</h1>
      <p className="text-t-muted">Pendiente de migrar (UI completa).</p>
    </div>
  );
};
