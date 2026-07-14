// Shared condition builder used by the Segment editor and the Drip step editor.
// Renders the operator + leaf-condition tree against a list of customer
// attributes. Extracted so both surfaces stay in sync.
import { Plus, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  ConditionGroup, LeafCondition, Attribute, ConditionOperator, GroupOperator,
} from '@/api/segments';

// ID generator — no external deps
export const uid = () => Math.random().toString(36).slice(2, 10);

const STRING_OPERATORS: { value: ConditionOperator; label: string }[] = [
  { value: 'equals', label: 'equals' },
  { value: 'not_equals', label: 'does not equal' },
  { value: 'contains', label: 'contains' },
  { value: 'not_contains', label: 'does not contain' },
  { value: 'is_blank', label: 'is blank' },
  { value: 'is_present', label: 'is present' },
];

const DATE_OPERATORS: { value: ConditionOperator; label: string }[] = [
  { value: 'equals', label: 'on' },
  { value: 'before', label: 'before' },
  { value: 'after', label: 'after' },
];

const NO_VALUE_OPS: ConditionOperator[] = ['is_blank', 'is_present'];

export function operatorsFor(attrType: 'string' | 'date'): { value: ConditionOperator; label: string }[] {
  return attrType === 'date' ? DATE_OPERATORS : STRING_OPERATORS;
}

export function newLeaf(attrs: Attribute[]): LeafCondition {
  const firstAttr = attrs[0] ?? { key: 'email', type: 'string' as const };
  const ops = operatorsFor(firstAttr.type);
  return { id: uid(), attribute: firstAttr.key, operator: ops[0].value, value: '' };
}

export function newGroup(): ConditionGroup {
  return { id: uid(), operator: 'and', conditions: [] };
}

export function isGroup(c: LeafCondition | ConditionGroup): c is ConditionGroup {
  return 'conditions' in c;
}

// Strip local `id` fields before sending to backend
export function serialiseGroup(group: ConditionGroup): object {
  return {
    operator: group.operator,
    conditions: group.conditions.map(c =>
      isGroup(c)
        ? serialiseGroup(c)
        : { attribute: c.attribute, operator: c.operator, value: c.value }
    ),
  };
}

// Re-hydrate a serialised group from the backend with local React-key ids.
export function hydrateGroup(g: any): ConditionGroup {
  return {
    id: uid(),
    operator: g?.operator || 'and',
    conditions: (g?.conditions || []).map((c: any) =>
      c.conditions
        ? hydrateGroup(c)
        : { id: uid(), attribute: c.attribute || 'email', operator: c.operator || 'equals', value: c.value || '' }
    ),
  };
}

// --- Leaf condition row ---
function ConditionRow({
  condition,
  attributes,
  onChange,
  onRemove,
}: {
  condition: LeafCondition;
  attributes: Attribute[];
  onChange: (c: LeafCondition) => void;
  onRemove: () => void;
}) {
  const attr = attributes.find(a => a.key === condition.attribute);
  const ops = operatorsFor(attr?.type ?? 'string');
  const showValue = !NO_VALUE_OPS.includes(condition.operator);

  const handleAttrChange = (key: string) => {
    const newAttr = attributes.find(a => a.key === key);
    const newOps = operatorsFor(newAttr?.type ?? 'string');
    onChange({ ...condition, attribute: key, operator: newOps[0].value, value: '' });
  };

  return (
    <div className="flex items-center gap-2 flex-wrap">
      <Select value={condition.attribute} onValueChange={handleAttrChange}>
        <SelectTrigger className="w-40 h-8 text-sm">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {attributes.map(a => (
            <SelectItem key={a.key} value={a.key}>{a.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>

      <Select
        value={condition.operator}
        onValueChange={v => onChange({ ...condition, operator: v as ConditionOperator, value: '' })}
      >
        <SelectTrigger className="w-44 h-8 text-sm">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {ops.map(o => (
            <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>

      {showValue && (
        attr?.type === 'date' ? (
          <Input
            type="date"
            className="w-40 h-8 text-sm"
            value={condition.value}
            onChange={e => onChange({ ...condition, value: e.target.value })}
          />
        ) : (
          <Input
            className="w-44 h-8 text-sm"
            placeholder="Value…"
            value={condition.value}
            onChange={e => onChange({ ...condition, value: e.target.value })}
          />
        )
      )}

      <Button
        variant="ghost"
        size="sm"
        className="h-8 w-8 p-0 text-muted-foreground hover:text-destructive"
        onClick={onRemove}
      >
        <Trash2 className="h-3.5 w-3.5" />
      </Button>
    </div>
  );
}

// --- Condition group (recursive) ---
export function ConditionGroupBlock({
  group,
  attributes,
  onChange,
  onRemove,
  depth = 0,
}: {
  group: ConditionGroup;
  attributes: Attribute[];
  onChange: (g: ConditionGroup) => void;
  onRemove?: () => void;
  depth?: number;
}) {
  const updateCondition = (idx: number, updated: LeafCondition | ConditionGroup) => {
    const next = [...group.conditions];
    next[idx] = updated;
    onChange({ ...group, conditions: next });
  };

  const removeCondition = (idx: number) => {
    onChange({ ...group, conditions: group.conditions.filter((_, i) => i !== idx) });
  };

  const addLeaf = () => {
    onChange({ ...group, conditions: [...group.conditions, newLeaf(attributes)] });
  };

  const addGroup = () => {
    onChange({ ...group, conditions: [...group.conditions, newGroup()] });
  };

  return (
    <div className={`rounded-lg border bg-card ${depth > 0 ? 'ml-4 p-3 border-dashed' : 'p-4'}`}>
      {/* Group header */}
      <div className="flex items-center gap-3 mb-4">
        {depth > 0 && <span className="text-xs text-muted-foreground font-medium">Group</span>}
        <div className="flex items-center gap-1 bg-muted rounded-md p-0.5">
          {(['and', 'or'] as GroupOperator[]).map(op => (
            <button
              key={op}
              onClick={() => onChange({ ...group, operator: op })}
              className={`px-3 py-1 rounded text-xs font-semibold transition-colors ${
                group.operator === op
                  ? 'bg-background shadow text-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {op.toUpperCase()}
            </button>
          ))}
        </div>
        <span className="text-xs text-muted-foreground">of the following conditions are true</span>
        {onRemove && (
          <Button
            variant="ghost"
            size="sm"
            className="h-7 w-7 p-0 ml-auto text-muted-foreground hover:text-destructive"
            onClick={onRemove}
          >
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        )}
      </div>

      {/* Conditions */}
      <div className="space-y-3">
        {group.conditions.length === 0 && (
          <p className="text-sm text-muted-foreground italic py-2">No conditions yet. Add one below.</p>
        )}
        {group.conditions.map((c, idx) =>
          isGroup(c) ? (
            <ConditionGroupBlock
              key={c.id}
              group={c}
              attributes={attributes}
              onChange={updated => updateCondition(idx, updated)}
              onRemove={() => removeCondition(idx)}
              depth={depth + 1}
            />
          ) : (
            <ConditionRow
              key={c.id}
              condition={c}
              attributes={attributes}
              onChange={updated => updateCondition(idx, updated)}
              onRemove={() => removeCondition(idx)}
            />
          )
        )}
      </div>

      {/* Add buttons */}
      <div className="flex items-center gap-2 mt-4 pt-3 border-t border-dashed">
        <Button variant="outline" size="sm" className="h-7 text-xs" onClick={addLeaf}>
          <Plus className="h-3 w-3 mr-1" />
          Add Condition
        </Button>
        {depth === 0 && (
          <Button variant="ghost" size="sm" className="h-7 text-xs text-muted-foreground" onClick={addGroup}>
            <Plus className="h-3 w-3 mr-1" />
            Add Group
          </Button>
        )}
      </div>
    </div>
  );
}
