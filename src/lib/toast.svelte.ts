export interface ToastItem {
	id: number;
	text: string;
	kind: 'info' | 'error';
}

let next = 1;

class Toasts {
	items = $state<ToastItem[]>([]);

	show(text: string, kind: ToastItem['kind'] = 'info', ms = 3200): void {
		const item = { id: next++, text, kind };
		this.items = [...this.items.slice(-2), item];
		setTimeout(() => this.dismiss(item.id), ms);
	}

	dismiss(id: number): void {
		this.items = this.items.filter((t) => t.id !== id);
	}
}

export const toasts = new Toasts();
