export const apiHeaders = (key: string) => ({
  'Content-Type': 'application/json',
  'x-screentutor-client': 'web',
  ...(key ? { 'x-provider-key': key } : {}),
});
export async function responseError(response: Response): Promise<Error> {
  const body = await response.json().catch(() => null);
  return new Error(
    typeof body?.error === 'string' ? body.error : `Request failed (HTTP ${response.status}).`,
  );
}
