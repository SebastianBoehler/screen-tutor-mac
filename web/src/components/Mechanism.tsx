import { ArrowDown } from 'lucide-react';
import type { ActivityContent } from '../domain/schema';
import { ArtifactFrame } from './ArtifactFrame';

export function Mechanism({ diagram }: { diagram: NonNullable<ActivityContent['diagram']> }) {
  return (
    <ArtifactFrame
      title="Process diagram"
      preview={
        <p className="preview-process">
          {diagram.nodes.map((node, index) => (
            <span key={index}>
              {index > 0 && <span aria-hidden="true"> → </span>}
              {node.label}
            </span>
          ))}
        </p>
      }
    >
      <figure className="mechanism" aria-label="Concept mechanism">
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
    </ArtifactFrame>
  );
}
