import { cva, type VariantProps } from 'class-variance-authority'

export { default as Button } from './Button.vue'

export const buttonVariants = cva(
  'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-lg text-xs font-medium transition-all duration-200 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary/60 disabled:pointer-events-none disabled:opacity-50 active:scale-[0.98]',
  {
    variants: {
      variant: {
        default:
          'bg-primary text-on-primary font-semibold shadow-[0_0_20px_rgba(125,211,252,0.25)] hover:bg-primary-fixed hover:shadow-[0_0_25px_rgba(125,211,252,0.4)]',
        tertiary:
          'bg-tertiary-fixed text-on-tertiary-fixed font-semibold shadow-[0_0_20px_rgba(200,160,240,0.2)] hover:brightness-110',
        glass:
          'bg-primary/15 text-primary font-semibold hover:bg-primary/25 shadow-sm',
        secondary:
          'bg-surface-container-high text-on-surface hover:bg-surface-variant shadow-sm',
        outline:
          'border border-outline-variant/60 bg-surface-container/40 text-on-surface hover:bg-surface-variant/50',
        ghost:
          'text-on-surface-variant hover:text-on-surface hover:bg-surface-variant/40',
        destructive:
          'bg-error-container/60 text-on-error-container font-semibold hover:bg-error-container',
        link: 'text-primary underline-offset-4 hover:underline shadow-none'
      },
      size: {
        default: 'px-4 py-2 text-xs',
        sm: 'px-3 py-1.5 text-[11px]',
        xs: 'px-2.5 py-1 text-[11px] rounded-md',
        lg: 'px-5 py-2.5 text-sm',
        icon: 'h-8 w-8 p-0'
      }
    },
    defaultVariants: {
      variant: 'default',
      size: 'default'
    }
  }
)

export type ButtonVariants = VariantProps<typeof buttonVariants>
