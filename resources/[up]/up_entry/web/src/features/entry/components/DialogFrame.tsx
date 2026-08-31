import { useEffect } from 'react'

interface DialogFrameProps extends React.PropsWithChildren {
  labelledBy: string
  onClose: () => void
  locked: boolean
  className?: string
}

export function DialogFrame({ children, labelledBy, onClose, locked, className = '' }: DialogFrameProps) {
  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !locked) onClose()
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => window.removeEventListener('keydown', closeOnEscape)
  }, [locked, onClose])

  return (
    <div className="dialog-backdrop">
      <section className={`entry-dialog ${className}`} role="dialog" aria-modal="true" aria-labelledby={labelledBy}>
        {children}
      </section>
    </div>
  )
}
