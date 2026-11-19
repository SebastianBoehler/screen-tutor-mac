import { ArrowDown } from 'lucide-react';
import type { ActivityContent } from '../domain/schema';

export function Mechanism({ diagram }: { diagram: NonNullable<ActivityContent['diagram']> }) {
  return (
    <figure className="mechanism" aria-label="Concept mechanism">
      <figcaption>Process diagram</figcaption>
      {diagram.nodes.map((node, index) => (
        <div className="mechanism-step" key={index}>
          <div className="mechanism-node">
            <span className="step-number">{String(index + 1).padStart(2, '0')}</span>
            <div>
              <strong>{node.label}</strong>
              <p>{node.detail}</p>
            </div>
          </div>
          {diagram.links
            .filter((link) => link.from === index)
            .map((link, i) => (
              <div className="mechanism-link" key={i}>
                <ArrowDown size={16} aria-hidden="true" />
                <span>
                  {link.label} → {diagram.nodes[link.to]?.label}
                </span>
              </div>
            ))}
        </div>
      ))}
    </figure>
  );
}
