export const PlaceholderPage = ({ title }: { title: string }) => {
  return (
    <div className="space-y-2">
      <h1 className="text-3xl font-bold text-gray-900">{title}</h1>
      <p className="text-gray-600">Pendiente de migrar (UI completa).</p>
    </div>
  );
};
