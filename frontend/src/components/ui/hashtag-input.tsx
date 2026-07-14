import { useState, KeyboardEvent, ClipboardEvent } from 'react';
import { X } from 'lucide-react';
import { Input } from '@/components/ui/input';

interface HashtagInputProps {
  value: string[];
  onChange: (next: string[]) => void;
  placeholder?: string;
}

// Normalise a raw token into a single #hashtag (no spaces, one leading #).
const normalize = (raw: string): string => {
  const t = raw.trim().replace(/\s+/g, '').replace(/^#+/, '');
  return t ? `#${t}` : '';
};

// A chip input for hashtags. Type and press Enter/space/comma to add, or paste a
// whole list (whitespace/comma separated) at once.
export function HashtagInput({ value, onChange, placeholder }: HashtagInputProps) {
  const [input, setInput] = useState('');

  const addMany = (raw: string) => {
    const additions = raw
      .split(/[\s,]+/)
      .map(normalize)
      .filter((t) => t.length > 1);
    if (additions.length === 0) return;
    const seen = new Set(value.map((t) => t.toLowerCase()));
    const next = [...value];
    for (const t of additions) {
      if (!seen.has(t.toLowerCase())) {
        seen.add(t.toLowerCase());
        next.push(t);
      }
    }
    onChange(next);
    setInput('');
  };

  const onKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',' || e.key === ' ') {
      e.preventDefault();
      addMany(input);
    } else if (e.key === 'Backspace' && input === '' && value.length > 0) {
      onChange(value.slice(0, -1));
    }
  };

  const onPaste = (e: ClipboardEvent<HTMLInputElement>) => {
    const text = e.clipboardData.getData('text');
    if (/[\s,]/.test(text)) {
      e.preventDefault();
      addMany(`${input}${text}`);
    }
  };

  return (
    <div className="space-y-2">
      {value.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {value.map((tag) => (
            <span key={tag} className="flex items-center gap-1 rounded-md bg-muted px-2 py-0.5 text-sm">
              {tag}
              <button type="button" onClick={() => onChange(value.filter((t) => t !== tag))}>
                <X className="h-3 w-3 text-muted-foreground hover:text-destructive" />
              </button>
            </span>
          ))}
        </div>
      )}
      <Input
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={onKeyDown}
        onPaste={onPaste}
        onBlur={() => addMany(input)}
        placeholder={placeholder ?? 'Paste or type hashtags…'}
      />
    </div>
  );
}
