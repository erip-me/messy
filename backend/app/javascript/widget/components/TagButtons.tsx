import { h } from 'preact';
import type { Tag } from '../types';

interface Props {
  tags: Tag[];
  onTagClick: (tagId: number) => void;
  disabled: boolean;
}

export function TagButtons({ tags, onTagClick, disabled }: Props) {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
      {tags.map((tag) => (
        <button
          key={tag.id}
          onClick={() => !disabled && onTagClick(tag.id)}
          disabled={disabled}
          style={{
            padding: '8px 16px',
            borderRadius: '20px',
            border: `1px solid ${tag.color}`,
            backgroundColor: 'white',
            color: tag.color,
            fontSize: '13px',
            cursor: disabled ? 'default' : 'pointer',
            opacity: disabled ? 0.5 : 1,
            transition: 'background-color 0.2s',
          }}
        >
          {tag.name}
        </button>
      ))}
    </div>
  );
}
