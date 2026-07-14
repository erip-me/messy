import { Skeleton } from '@/components/ui/skeleton';
import { Card, CardContent } from '@/components/ui/card';

interface TableSkeletonProps {
  columns?: number;
  rows?: number;
  showHeader?: boolean;
  showActions?: boolean;
}

export function TableSkeleton({ columns = 4, rows = 8, showHeader = true, showActions = true }: TableSkeletonProps) {
  return (
    <Card className="card-shadow bg-white overflow-hidden">
      {/* Header skeleton */}
      {showHeader && (
        <div className="bg-muted/30 px-4 py-3 flex items-center gap-4">
          {Array.from({ length: columns }).map((_, i) => (
            <Skeleton key={i} className="h-3 rounded" style={{ width: `${i === 0 ? 30 : 15 + Math.random() * 10}%` }} />
          ))}
        </div>
      )}
      {/* Row skeletons */}
      <div className="divide-y divide-gray-100/80">
        {Array.from({ length: rows }).map((_, rowIdx) => (
          <div key={rowIdx} className="px-4 py-3 flex items-center gap-4">
            {Array.from({ length: columns }).map((_, colIdx) => (
              <Skeleton
                key={colIdx}
                className="h-4 rounded"
                style={{
                  width: colIdx === 0 ? '35%' : `${12 + (colIdx * 5)}%`,
                  opacity: 1 - rowIdx * 0.06,
                }}
              />
            ))}
            {showActions && (
              <Skeleton className="h-4 w-4 rounded ml-auto" style={{ opacity: 1 - rowIdx * 0.06 }} />
            )}
          </div>
        ))}
      </div>
    </Card>
  );
}

interface CardGridSkeletonProps {
  cards?: number;
  cols?: number;
}

export function CardGridSkeleton({ cards = 6, cols = 3 }: CardGridSkeletonProps) {
  return (
    <div className={`grid grid-cols-1 md:grid-cols-2 lg:grid-cols-${cols} gap-6`}>
      {Array.from({ length: cards }).map((_, i) => (
        <Card key={i} className="card-shadow bg-white overflow-hidden">
          <CardContent className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <Skeleton className="h-5 w-32 rounded" />
              <Skeleton className="h-6 w-16 rounded-full" />
            </div>
            <Skeleton className="h-3 w-full rounded" />
            <Skeleton className="h-3 w-3/4 rounded" />
            <div className="flex gap-2 pt-2">
              <Skeleton className="h-8 w-20 rounded" />
              <Skeleton className="h-8 w-20 rounded" />
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

interface PageSkeletonProps {
  title?: boolean;
  actions?: number;
  columns?: number;
  rows?: number;
  variant?: 'table' | 'cards';
  cards?: number;
  cols?: number;
}

export function PageSkeleton({ title = true, actions = 2, columns = 4, rows = 8, variant = 'table', cards = 6, cols = 3 }: PageSkeletonProps) {
  return (
    <div className="p-6 bg-white min-h-screen">
      <div className="flex justify-between items-center mb-6">
        {title && <Skeleton className="h-8 w-48" />}
        {actions > 0 && (
          <div className="flex gap-2">
            {Array.from({ length: actions }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-32 rounded-md" />
            ))}
          </div>
        )}
      </div>
      {variant === 'cards' ? (
        <CardGridSkeleton cards={cards} cols={cols} />
      ) : (
        <TableSkeleton columns={columns} rows={rows} />
      )}
    </div>
  );
}
