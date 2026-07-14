import { useState, useCallback, useRef } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface ConfirmOptions {
  title?: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: "default" | "destructive";
}

interface ConfirmState extends ConfirmOptions {
  open: boolean;
}

export function useConfirm() {
  const [state, setState] = useState<ConfirmState>({
    open: false,
    description: "",
  });

  const resolveRef = useRef<((value: boolean) => void) | null>(null);

  const confirm = useCallback((options: ConfirmOptions): Promise<boolean> => {
    return new Promise<boolean>((resolve) => {
      resolveRef.current = resolve;
      setState({ ...options, open: true });
    });
  }, []);

  const handleClose = useCallback((confirmed: boolean) => {
    setState((prev) => ({ ...prev, open: false }));
    resolveRef.current?.(confirmed);
    resolveRef.current = null;
  }, []);

  const ConfirmDialog = (
    <Dialog open={state.open} onOpenChange={(open) => !open && handleClose(false)}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{state.title || "Are you sure?"}</DialogTitle>
          <DialogDescription>{state.description}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => handleClose(false)}>
            {state.cancelLabel || "Cancel"}
          </Button>
          <Button
            variant={state.variant === "destructive" ? "destructive" : "default"}
            onClick={() => handleClose(true)}
          >
            {state.confirmLabel || "Confirm"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );

  return { confirm, ConfirmDialog };
}
