import { h } from 'preact';
import type { Operator } from '../types';

interface Props {
  operators: Operator[];
  primaryColor: string;
}

export function OperatorAvatars({ operators, primaryColor }: Props) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0' }}>
      {operators.slice(0, 4).map((op, i) => (
        <div
          key={op.id}
          style={{
            width: '40px',
            height: '40px',
            borderRadius: '50%',
            backgroundColor: primaryColor,
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '16px',
            fontWeight: 'bold',
            border: '3px solid white',
            marginLeft: i > 0 ? '-10px' : '0',
            backgroundImage: op.avatar_url ? `url(${op.avatar_url})` : 'none',
            backgroundSize: 'cover',
            position: 'relative',
          }}
          title={op.name}
        >
          {!op.avatar_url && op.name.charAt(0).toUpperCase()}
          <div
            style={{
              position: 'absolute',
              bottom: '0',
              right: '0',
              width: '10px',
              height: '10px',
              borderRadius: '50%',
              backgroundColor: '#22C55E',
              border: '2px solid white',
            }}
          />
        </div>
      ))}
    </div>
  );
}
