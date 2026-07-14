import { h } from 'preact';
import { useState } from 'preact/hooks';

interface Props {
  onSubmit: (name: string, email: string, message: string) => Promise<void>;
  primaryColor: string;
  sendButtonColor?: string;
  sendButtonTextColor?: string;
}

export function OfflineForm({ onSubmit, primaryColor, sendButtonColor, sendButtonTextColor }: Props) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: Event) {
    e.preventDefault();
    if (!name.trim() || !email.trim() || !message.trim()) return;

    setSubmitting(true);
    try {
      await onSubmit(name.trim(), email.trim(), message.trim());
      setSubmitted(true);
    } catch (err) {
      console.error('Failed to submit offline form', err);
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <div style={{ textAlign: 'center', padding: '20px 0' }}>
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>✓</div>
        <p style={{ color: '#374151', fontSize: '14px', fontWeight: '500' }}>Message sent!</p>
        <p style={{ color: '#6B7280', fontSize: '13px' }}>We'll get back to you at {email}</p>
      </div>
    );
  }

  const inputStyle = {
    width: '100%',
    padding: '10px 12px',
    borderRadius: '8px',
    border: '1px solid #D1D5DB',
    fontSize: '14px',
    outline: 'none',
    boxSizing: 'border-box' as const,
    marginBottom: '10px',
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Your name"
        value={name}
        onInput={(e) => setName((e.target as HTMLInputElement).value)}
        style={inputStyle}
        required
      />
      <input
        type="email"
        placeholder="Your email"
        value={email}
        onInput={(e) => setEmail((e.target as HTMLInputElement).value)}
        style={inputStyle}
        required
      />
      <textarea
        placeholder="Your message"
        value={message}
        onInput={(e) => setMessage((e.target as HTMLTextAreaElement).value)}
        style={{ ...inputStyle, minHeight: '80px', resize: 'vertical' }}
        required
      />
      <button
        type="submit"
        disabled={submitting}
        style={{
          width: '100%',
          padding: '10px',
          borderRadius: '8px',
          backgroundColor: sendButtonColor || primaryColor,
          color: sendButtonTextColor || 'white',
          border: 'none',
          fontSize: '14px',
          fontWeight: '500',
          cursor: submitting ? 'default' : 'pointer',
          opacity: submitting ? 0.7 : 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '6px',
        }}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
        </svg>
        {submitting ? 'Sending...' : 'Send Message'}
      </button>
    </form>
  );
}
