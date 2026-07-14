import { type ReactNode } from 'react';
import { HelpCircle } from 'lucide-react';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';

// ponytail: click-to-open on the already-installed Popover instead of pulling in
// @radix-ui/react-tooltip. The trigger is a real <button>, so it works with a
// keyboard and on touch, which a hover tooltip does not. Swap in a Tooltip
// primitive only if hover-without-click becomes a real requirement.
export function HelpHint({ label, children }: { label: string; children: ReactNode }) {
  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label={label}
          className="inline-flex text-muted-foreground transition-colors hover:text-foreground"
        >
          <HelpCircle className="h-3.5 w-3.5" />
        </button>
      </PopoverTrigger>
      <PopoverContent
        align="start"
        className="max-w-xs p-3 text-xs leading-relaxed text-muted-foreground"
      >
        {children}
      </PopoverContent>
    </Popover>
  );
}
