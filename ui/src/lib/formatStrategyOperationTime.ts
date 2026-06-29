const TIME_FORMAT = /^([01]\d|2[0-3]):[0-5]\d$/;

export const formatStrategyOperationTime = (
  value?: string | null,
  empty = "—",
) => {
  const text = (value || "").trim();
  return TIME_FORMAT.test(text) ? text : empty;
};
