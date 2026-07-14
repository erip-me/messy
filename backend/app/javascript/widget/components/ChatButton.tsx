import { h } from 'preact';
import type { Operator } from '../types';

interface Props {
  onClick: () => void;
  unreadCount: number;
  operators: Operator[];
  buttonColor: string;
  buttonTextColor: string;
  position: string;
}

export function ChatButton({ onClick, unreadCount, operators, buttonColor, buttonTextColor, position }: Props) {
  const posStyle = position === 'bottom-left' ? { left: '20px' } : { right: '20px' };

  return (
    <div
      class="messy-chat-button"
      onClick={onClick}
      style={{
        position: 'fixed',
        bottom: '20px',
        ...posStyle,
        zIndex: 2147483647,
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
      }}
    >
      {operators.length > 0 && (
        <div style={{ display: 'flex', marginRight: '-4px' }}>
          {operators.slice(0, 3).map((op, i) => (
            <div
              key={op.id}
              style={{
                width: '28px',
                height: '28px',
                borderRadius: '50%',
                backgroundColor: buttonColor,
                color: buttonTextColor,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '12px',
                fontWeight: 'bold',
                border: '2px solid white',
                marginLeft: i > 0 ? '-8px' : '0',
                backgroundImage: op.avatar_url ? `url(${op.avatar_url})` : 'none',
                backgroundSize: 'cover',
              }}
            >
              {!op.avatar_url && op.name.charAt(0)}
            </div>
          ))}
        </div>
      )}
      <div
        style={{
          width: '56px',
          height: '56px',
          borderRadius: '50%',
          backgroundColor: buttonColor,
          color: buttonTextColor,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
          position: 'relative',
        }}
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
        {unreadCount > 0 && (
          <div
            style={{
              position: 'absolute',
              top: '-4px',
              right: '-4px',
              backgroundColor: '#EF4444',
              color: 'white',
              borderRadius: '50%',
              width: '20px',
              height: '20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '11px',
              fontWeight: 'bold',
            }}
          >
            {unreadCount > 9 ? '9+' : unreadCount}
          </div>
        )}
      </div>
    </div>
  );
}
