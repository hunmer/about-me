import { cva, type VariantProps } from 'class-variance-authority'

export { default as Badge } from './Badge.vue'

export const badgeVariants = cva(
  'inline-flex items-center gap-1 rounded-full font-mono whitespace-nowrap',
  {
    variants: {
      variant: {
        default: 'bg-primary-container text-on-primary-container',
        glass: 'bg-primary/15 text-primary',
        outline: 'border border-outline-variant/60 text-on-surface-variant',
        secondary: 'bg-surface-container-highest text-secondary',
        tertiary: 'bg-tertiary-container text-on-tertiary-container',
        neutral: 'bg-surface-variant text-on-surface-variant',
        success: 'bg-primary/20 text-primary',
        error: 'bg-error-container/60 text-error',
        warn: 'bg-tertiary-container/40 text-tertiary'
      },
      size: {
        default: 'px-2.5 py-0.5 text-[11px]',
        sm: 'px-2 py-0.5 text-[10px]',
        lg: 'px-3 py-1 text-xs'
      }
    },
    defaultVariants: {
      variant: 'default',
      size: 'default'
    }
  }
)

export type BadgeVariants = VariantProps<typeof badgeVariants>
