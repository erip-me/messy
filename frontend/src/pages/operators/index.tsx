import { OperatorOrder } from "../chat-settings/operator-order";

export function OperatorsPage() {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="page-heading">Operators</h1>
        <p className="page-subtitle">
          Manage operator priority and auto-assignment order. This applies to both chat conversations and email tickets.
        </p>
      </div>
      <OperatorOrder />
    </div>
  );
}
