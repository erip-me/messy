import { LucideIcon } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface MetricTileProps {
  title: string;
  value: React.ReactNode;
  subtitle?: React.ReactNode;
  icon: LucideIcon;
  /** Tailwind classes for the icon's rounded background box, e.g. "bg-blue-100". */
  iconWrapClassName: string;
  /** Tailwind classes for the icon itself, e.g. "text-blue-600". */
  iconClassName: string;
  onClick?: () => void;
}

/** Compact "big number" stat card used across the dashboard overview grid. */
export function MetricTile({
  title,
  value,
  subtitle,
  icon: Icon,
  iconWrapClassName,
  iconClassName,
  onClick,
}: MetricTileProps) {
  return (
    <Card
      className={`card-shadow bg-card ${onClick ? 'cursor-pointer hover:shadow-md transition-shadow' : ''}`}
      onClick={onClick}
    >
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${iconWrapClassName}`}>
          <Icon className={`h-4 w-4 ${iconClassName}`} />
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold tracking-tight text-foreground tabular-nums">{value}</div>
        {subtitle && <p className="text-xs text-muted-foreground mt-1 font-mono">{subtitle}</p>}
      </CardContent>
    </Card>
  );
}
