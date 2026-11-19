import { useState } from 'react';
import type { Material } from '../domain/models';
import { Dialog } from './Dialog';

export function Source({
  material,
  initialPage,
  onClose,
}: {
  material: Material;
  initialPage: number;
  onClose(): void;
}) {
  const [page, setPage] = useState(initialPage);
  return (
    <Dialog title={material.name} onClose={onClose}>
      <div className="row between">
        <span className="eyebrow">
          {material.kind === 'lecture-note' ? 'Your lecture note' : 'Extracted source text'}
        </span>
        <label className="page-select">
          Page
          <select
            aria-label="Source page"
            value={page}
            onChange={(event) => setPage(Number(event.target.value))}
          >
            {material.pages.map((item) => (
              <option key={item.number}>{item.number}</option>
            ))}
          </select>
        </label>
      </div>
      <pre className="source-text">
        {material.pages.find((item) => item.number === page)?.text ||
          'This page has no extractable text.'}
      </pre>
    </Dialog>
  );
}
