import { uid, now, type Material } from '../domain/models';

const maxBytes = 25 * 1024 * 1024;
export async function importMaterial(file: File, courseId: string): Promise<Material> {
  if (file.size > maxBytes) throw new Error('Choose a file smaller than 25 MB.');
  const bytes = await file.arrayBuffer();
  const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
  let pages: Material['pages'];
  if (/\.pdf$/i.test(file.name)) {
    const pdfjs = await import('pdfjs-dist');
    pdfjs.GlobalWorkerOptions.workerSrc = new URL(
      'pdfjs-dist/build/pdf.worker.min.mjs',
      import.meta.url,
    ).href;
    const pdf = await pdfjs.getDocument({ data: bytes }).promise;
    try {
      if (pdf.numPages > 600) throw new Error('Choose a PDF with at most 600 pages.');
      pages = [];
      for (let number = 1; number <= pdf.numPages; number++) {
        const page = await pdf.getPage(number);
        const content = await page.getTextContent();
        pages.push({
          number,
          text: content.items.map((item) => ('str' in item ? item.str : '')).join(' '),
        });
      }
    } finally {
      await pdf.destroy();
    }
  } else if (/\.(txt|md|markdown)$/i.test(file.name)) {
    pages = [
      {
        number: 1,
        text: new TextDecoder('utf-8', { fatal: true }).decode(bytes),
      },
    ];
  } else throw new Error('Supported materials: PDF, Markdown and plain text.');
  if (!pages.some((page) => page.text.trim().length > 20)) {
    throw new Error(
      'No readable text was found. Scanned PDFs need text recognition before import.',
    );
  }
  if (pages.reduce((sum, page) => sum + page.text.length, 0) > 3_000_000)
    throw new Error('The extracted text is too large. Split this material into smaller files.');
  return {
    id: uid(),
    courseId,
    name: file.name,
    hash,
    kind: 'document',
    createdAt: now(),
    pages,
  };
}
