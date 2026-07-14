import { h } from 'preact';
import { useState, useEffect, useRef } from 'preact/hooks';

interface Props {
  onSend: (content: string) => void;
  onEscape?: () => void;
  disabled: boolean;
  placeholder: string;
  primaryColor: string;
  sendButtonColor?: string;
  sendButtonTextColor?: string;
  autoFocus?: boolean;
}

export function MessageInput({ onSend, onEscape, disabled, placeholder, primaryColor, sendButtonColor, sendButtonTextColor, autoFocus }: Props) {
  const [value, setValue] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (autoFocus) {
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [autoFocus]);

  function handleSubmit(e: Event) {
    e.preventDefault();
    if (value.trim() && !disabled) {
      onSend(value.trim());
      setValue('');
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
    if (e.key === 'Escape' && onEscape) {
      onEscape();
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      style={{
        display: 'flex',
        alignItems: 'center',
        padding: '12px 16px',
        paddingBottom: 'max(12px, env(safe-area-inset-bottom, 12px))',
        borderTop: '1px solid #E5E7EB',
        backgroundColor: '#FAFAFA',
      }}
    >
      <input
        ref={inputRef}
        type="text"
        value={value}
        onInput={(e) => setValue((e.target as HTMLInputElement).value)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        disabled={disabled}
        style={{
          flex: 1,
          border: '1px solid #D1D5DB',
          borderRadius: '20px',
          padding: '10px 16px',
          fontSize: '14px',
          outline: 'none',
          backgroundColor: 'white',
        }}
      />
      <button
        type="submit"
        disabled={disabled || !value.trim()}
        style={{
          marginLeft: '8px',
          width: '36px',
          height: '36px',
          borderRadius: '50%',
          backgroundColor: value.trim() ? (sendButtonColor || primaryColor) : '#D1D5DB',
          color: sendButtonTextColor || 'white',
          border: 'none',
          cursor: value.trim() && !disabled ? 'pointer' : 'default',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
        </svg>
      </button>
    </form>
  );
}
