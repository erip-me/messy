import { useState } from 'react';
import { Check, Plus, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { COUNTRIES, countryFlag, countryName } from '@/lib/countries';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';

// Multi-select of countries with flags. Stores ISO 3166-1 alpha-2 codes; shows
// flags + names in the UI.
export function CountryMultiSelect({
  value,
  onChange,
}: {
  value: string[];
  onChange: (codes: string[]) => void;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');

  const q = query.trim().toLowerCase();
  const filtered = q
    ? COUNTRIES.filter((c) => c.name.toLowerCase().includes(q) || c.code.toLowerCase().includes(q))
    : COUNTRIES;

  const toggle = (code: string) =>
    onChange(value.includes(code) ? value.filter((v) => v !== code) : [...value, code]);

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-1">
        {value.length === 0 ? (
          <span className="text-xs text-muted-foreground">No countries selected</span>
        ) : (
          value.map((code) => (
            <Badge key={code} variant="secondary" className="gap-1">
              <span>{countryFlag(code)}</span>
              {countryName(code)}
              <button type="button" onClick={() => toggle(code)} className="ml-0.5 hover:text-destructive">
                <X className="h-3 w-3" />
              </button>
            </Badge>
          ))
        )}
      </div>

      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button type="button" variant="outline" size="sm">
            <Plus className="mr-2 h-4 w-4" /> Add country
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-72 p-0" align="start">
          <Input
            autoFocus
            placeholder="Search countries…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="rounded-none border-0 border-b focus-visible:ring-0"
          />
          <ScrollArea className="h-64">
            {filtered.length === 0 ? (
              <p className="px-3 py-4 text-sm text-muted-foreground">No matches</p>
            ) : (
              filtered.map((c) => (
                <button
                  key={c.code}
                  type="button"
                  onClick={() => toggle(c.code)}
                  className={cn(
                    'flex w-full items-center gap-2 px-3 py-1.5 text-sm hover:bg-muted',
                    value.includes(c.code) && 'bg-muted/50',
                  )}
                >
                  <span className="text-base">{c.flag}</span>
                  <span className="flex-1 truncate text-left">{c.name}</span>
                  <span className="text-xs text-muted-foreground">{c.code}</span>
                  {value.includes(c.code) && <Check className="h-4 w-4 text-primary" />}
                </button>
              ))
            )}
          </ScrollArea>
        </PopoverContent>
      </Popover>
    </div>
  );
}
