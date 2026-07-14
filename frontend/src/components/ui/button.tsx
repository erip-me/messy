import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

// Tactile "clicky" chrome: rectangular corners + a hard offset shadow in a
// darker shade of the variant's own brand color (via color-mix, so no new
// colors are introduced — primary stays blue, destructive stays red, etc.).
// On press the button translates into its shadow, which reads as a physical
// push. Applied to the solid/outline variants; ghost/link stay flat.
const clicky =
  "active:translate-x-[3px] active:translate-y-[3px] active:shadow-none"

const buttonVariants = cva(
  "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-all duration-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: `bg-primary text-primary-foreground shadow-[3px_3px_0_0_color-mix(in_oklab,hsl(var(--primary))_62%,#000)] hover:bg-primary/90 ${clicky}`,
        destructive: `bg-destructive text-destructive-foreground shadow-[3px_3px_0_0_color-mix(in_oklab,hsl(var(--destructive))_62%,#000)] hover:bg-destructive/90 ${clicky}`,
        outline: `border-2 border-input bg-background shadow-[3px_3px_0_0_hsl(var(--border))] hover:bg-accent hover:text-accent-foreground ${clicky}`,
        secondary: `bg-secondary text-secondary-foreground shadow-[3px_3px_0_0_color-mix(in_oklab,hsl(var(--secondary))_78%,#000)] hover:bg-secondary/80 ${clicky}`,
        ghost: "rounded-md hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button"
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    )
  }
)
Button.displayName = "Button"

export { Button, buttonVariants }