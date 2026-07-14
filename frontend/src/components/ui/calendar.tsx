import * as React from "react"
import { ChevronLeft, ChevronRight } from "lucide-react"
import { DayPicker, useNavigation } from "react-day-picker"
import { format, setMonth, setYear, getYear, getMonth } from "date-fns"
import { cn } from "@/lib/utils"
import { buttonVariants } from "@/components/ui/button"

export type CalendarProps = React.ComponentProps<typeof DayPicker>

// ─── Month picker grid ────────────────────────────────────────────────────────
const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

function MonthPicker({ current, onSelect }: { current: Date; onSelect: (d: Date) => void }) {
  const currentM = getMonth(current)
  return (
    <div className="grid grid-cols-3 gap-1 p-2">
      {MONTHS.map((m, i) => (
        <button
          key={m}
          onClick={() => onSelect(setMonth(current, i))}
          className={cn(
            "rounded-md px-2 py-1.5 text-sm transition-colors hover:bg-accent hover:text-accent-foreground",
            i === currentM && "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground"
          )}
        >
          {m}
        </button>
      ))}
    </div>
  )
}

// ─── Year picker grid ─────────────────────────────────────────────────────────
function YearPicker({ current, onSelect }: { current: Date; onSelect: (d: Date) => void }) {
  const currentY = getYear(current)
  // Show a 4×3 grid of 12 years centred around the current year
  const [base, setBase] = React.useState(Math.floor(currentY / 12) * 12)
  const years = Array.from({ length: 12 }, (_, i) => base + i)

  return (
    <div className="p-2">
      <div className="flex items-center justify-between mb-2">
        <button
          onClick={() => setBase(b => b - 12)}
          className="rounded-md p-1 hover:bg-accent"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        <span className="text-xs font-medium text-muted-foreground">{base} – {base + 11}</span>
        <button
          onClick={() => setBase(b => b + 12)}
          className="rounded-md p-1 hover:bg-accent"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>
      <div className="grid grid-cols-3 gap-1">
        {years.map(y => (
          <button
            key={y}
            onClick={() => onSelect(setYear(current, y))}
            className={cn(
              "rounded-md px-2 py-1.5 text-sm transition-colors hover:bg-accent hover:text-accent-foreground",
              y === currentY && "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground"
            )}
          >
            {y}
          </button>
        ))}
      </div>
    </div>
  )
}

// ─── Custom caption ───────────────────────────────────────────────────────────
type CaptionView = "day" | "month" | "year"

function CustomCaption({ displayMonth }: { displayMonth: Date }) {
  const { goToMonth, nextMonth, previousMonth } = useNavigation()
  const [view, setView] = React.useState<CaptionView>("day")

  const handleMonthSelect = (d: Date) => {
    goToMonth(d)
    setView("day")
  }

  const handleYearSelect = (d: Date) => {
    goToMonth(d)
    setView("day")
  }

  return (
    <div>
      {/* Header row */}
      <div className="flex items-center justify-between px-1 mb-1">
        {view === "day" ? (
          <button
            onClick={() => previousMonth && goToMonth(previousMonth)}
            disabled={!previousMonth}
            className={cn(
              buttonVariants({ variant: "outline" }),
              "h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100"
            )}
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
        ) : (
          <div className="h-7 w-7" /> /* spacer */
        )}

        {/* Clickable month + year */}
        <div className="flex items-center gap-1">
          <button
            onClick={() => setView(v => v === "month" ? "day" : "month")}
            className={cn(
              "rounded px-1.5 py-0.5 text-sm font-semibold transition-colors hover:bg-accent",
              view === "month" && "bg-accent"
            )}
          >
            {format(displayMonth, "MMMM")}
          </button>
          <button
            onClick={() => setView(v => v === "year" ? "day" : "year")}
            className={cn(
              "rounded px-1.5 py-0.5 text-sm font-semibold transition-colors hover:bg-accent",
              view === "year" && "bg-accent"
            )}
          >
            {format(displayMonth, "yyyy")}
          </button>
        </div>

        {view === "day" ? (
          <button
            onClick={() => nextMonth && goToMonth(nextMonth)}
            disabled={!nextMonth}
            className={cn(
              buttonVariants({ variant: "outline" }),
              "h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100"
            )}
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        ) : (
          <div className="h-7 w-7" /> /* spacer */
        )}
      </div>

      {/* Sub-picker panels */}
      {view === "month" && (
        <MonthPicker current={displayMonth} onSelect={handleMonthSelect} />
      )}
      {view === "year" && (
        <YearPicker current={displayMonth} onSelect={handleYearSelect} />
      )}
    </div>
  )
}

// ─── Main Calendar ────────────────────────────────────────────────────────────
function Calendar({ className, classNames, showOutsideDays = true, ...props }: CalendarProps) {
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn("p-3", className)}
      classNames={{
        months: "flex flex-col sm:flex-row space-y-4 sm:space-x-4 sm:space-y-0",
        month: "space-y-4",
        caption: "flex justify-center pt-1 relative items-center",
        caption_label: "hidden", // hidden — replaced by CustomCaption
        nav: "hidden",           // hidden — nav handled inside CustomCaption
        nav_button: "hidden",
        nav_button_previous: "hidden",
        nav_button_next: "hidden",
        table: "w-full border-collapse space-y-1",
        head_row: "flex",
        head_cell: "text-muted-foreground rounded-md w-9 font-normal text-[0.8rem]",
        row: "flex w-full mt-2",
        cell: "h-9 w-9 text-center text-sm p-0 relative [&:has([aria-selected].day-range-end)]:rounded-r-md [&:has([aria-selected].day-outside)]:bg-accent/50 [&:has([aria-selected])]:bg-accent first:[&:has([aria-selected])]:rounded-l-md last:[&:has([aria-selected])]:rounded-r-md focus-within:relative focus-within:z-20",
        day: cn(
          buttonVariants({ variant: "ghost" }),
          "h-9 w-9 p-0 font-normal aria-selected:opacity-100"
        ),
        day_range_end: "day-range-end",
        day_selected:
          "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground focus:bg-primary focus:text-primary-foreground",
        day_today: "bg-accent text-accent-foreground",
        day_outside:
          "day-outside text-muted-foreground opacity-50 aria-selected:bg-accent/50 aria-selected:text-muted-foreground aria-selected:opacity-30",
        day_disabled: "text-muted-foreground opacity-50",
        day_range_middle: "aria-selected:bg-accent aria-selected:text-accent-foreground",
        day_hidden: "invisible",
        ...classNames,
      }}
      components={{
        Caption: CustomCaption,
      }}
      {...props}
    />
  )
}

Calendar.displayName = "Calendar"

export { Calendar }
