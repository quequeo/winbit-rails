import { useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'

export type SelectOption = {
  value: string
  label: string
  disabled?: boolean
}

type Props = {
  id?: string
  name?: string
  value: string
  options: SelectOption[]
  onChange: (nextValue: string) => void
  disabled?: boolean
  className?: string
  buttonClassName?: string
  portal?: boolean
}

export const Select = ({
  id,
  name,
  value,
  options,
  onChange,
  disabled = false,
  className = '',
  buttonClassName = '',
  portal = false,
}: Props) => {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const buttonRef = useRef<HTMLButtonElement | null>(null)
  const menuRef = useRef<HTMLDivElement | null>(null)
  const [open, setOpen] = useState(false)
  const [menuRect, setMenuRect] = useState<{ left: number; top: number; width: number } | null>(null)

  const items = useMemo(() => (Array.isArray(options) ? options : []), [options])

  const selected = useMemo(() => {
    return items.find((it) => String(it.value) === String(value)) ?? null
  }, [items, value])

  useEffect(() => {
    if (!open) return

    const updatePosition = () => {
      if (!portal) return
      const btn = buttonRef.current
      if (!btn) return
      const r = btn.getBoundingClientRect()
      setMenuRect({ left: r.left, top: r.bottom + 8, width: r.width })
    }

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }

    const onMouseDown = (e: MouseEvent) => {
      const t = e.target as Node
      const container = containerRef.current
      const menu = menuRef.current
      if (container?.contains(t)) return
      if (portal && menu?.contains(t)) return
      setOpen(false)
    }

    const onResize = () => updatePosition()
    const onScroll = () => updatePosition()

    document.addEventListener('keydown', onKeyDown)
    document.addEventListener('mousedown', onMouseDown)
    if (portal) {
      updatePosition()
      window.addEventListener('resize', onResize)
      // capture=true to catch scroll on nested containers
      window.addEventListener('scroll', onScroll, true)
    }
    return () => {
      document.removeEventListener('keydown', onKeyDown)
      document.removeEventListener('mousedown', onMouseDown)
      if (portal) {
        window.removeEventListener('resize', onResize)
        window.removeEventListener('scroll', onScroll, true)
      }
    }
  }, [open, portal])

  const selectValue = (nextValue: string) => {
    if (disabled) return
    setOpen(false)
    onChange(nextValue)
  }

  const displayLabel = selected?.label ?? items?.[0]?.label ?? ''

  return (
    <div className={className}>
      <div ref={containerRef} className="relative">
        <button
          id={id}
          name={name}
          type="button"
          ref={buttonRef}
          disabled={disabled}
          aria-haspopup="listbox"
          aria-expanded={open}
          onClick={() => {
            if (!disabled) setOpen((v) => !v)
          }}
          className={
            'flex h-10 w-full items-center justify-between gap-2 rounded-md border border-gray-300 bg-white px-3 text-left text-sm ' +
            'focus:border-[#58b098] focus:outline-none focus:ring-1 focus:ring-[#58b098] disabled:cursor-not-allowed disabled:bg-gray-100 ' +
            buttonClassName
          }
        >
          <span className="truncate text-gray-900">{displayLabel}</span>
          <svg
            viewBox="0 0 20 20"
            fill="currentColor"
            className={`h-4 w-4 shrink-0 ${disabled ? 'text-gray-300' : 'text-gray-400'}`}
            aria-hidden="true"
          >
            <path
              fillRule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.24a.75.75 0 01-1.06 0L5.21 8.29a.75.75 0 01.02-1.08z"
              clipRule="evenodd"
            />
          </svg>
        </button>

        {open
          ? portal
            ? createPortal(
                <div
                  ref={menuRef}
                  role="listbox"
                  aria-labelledby={id}
                  className="z-[9999] max-h-64 overflow-auto rounded-md border border-gray-200 bg-white shadow-lg"
                  style={{
                    position: 'fixed',
                    left: menuRect?.left ?? 0,
                    top: menuRect?.top ?? 0,
                    width: menuRect?.width ?? 0,
                  }}
                >
                  {items.map((opt) => {
                    const isSelected = String(opt.value) === String(value)
                    const optDisabled = !!opt.disabled
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        role="option"
                        aria-selected={isSelected}
                        disabled={optDisabled}
                        onClick={() => {
                          if (!optDisabled) selectValue(opt.value)
                        }}
                        className={
                          'w-full px-3 py-2 text-left text-sm ' +
                          (optDisabled ? 'cursor-not-allowed text-gray-300 ' : 'hover:bg-gray-50 ') +
                          (isSelected ? 'bg-[#58b098]/10 font-semibold text-gray-900' : 'text-gray-700')
                        }
                      >
                        {opt.label}
                      </button>
                    )
                  })}
                </div>,
                document.body,
              )
            : (
                <div
                  ref={menuRef}
                  role="listbox"
                  aria-labelledby={id}
                  className="absolute left-0 right-0 z-50 mt-2 max-h-64 overflow-auto rounded-md border border-gray-200 bg-white shadow-lg"
                >
                  {items.map((opt) => {
                    const isSelected = String(opt.value) === String(value)
                    const optDisabled = !!opt.disabled
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        role="option"
                        aria-selected={isSelected}
                        disabled={optDisabled}
                        onClick={() => {
                          if (!optDisabled) selectValue(opt.value)
                        }}
                        className={
                          'w-full px-3 py-2 text-left text-sm ' +
                          (optDisabled ? 'cursor-not-allowed text-gray-300 ' : 'hover:bg-gray-50 ') +
                          (isSelected ? 'bg-[#58b098]/10 font-semibold text-gray-900' : 'text-gray-700')
                        }
                      >
                        {opt.label}
                      </button>
                    )
                  })}
                </div>
              )
          : null}
      </div>
    </div>
  )
}

