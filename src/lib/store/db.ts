/** A tiny key-value store on IndexedDB. Everything the app keeps lives in this browser. */

const DB_NAME = 'custom-songless';
const STORE = 'kv';

let opening: Promise<IDBDatabase> | null = null;

function open(): Promise<IDBDatabase> {
	opening ??= new Promise((resolve, reject) => {
		const req = indexedDB.open(DB_NAME, 1);
		req.onupgradeneeded = () => req.result.createObjectStore(STORE);
		req.onsuccess = () => resolve(req.result);
		req.onerror = () => {
			opening = null;
			reject(req.error);
		};
	});
	return opening;
}

function run<T>(mode: IDBTransactionMode, fn: (store: IDBObjectStore) => IDBRequest): Promise<T> {
	return open().then(
		(db) =>
			new Promise<T>((resolve, reject) => {
				const req = fn(db.transaction(STORE, mode).objectStore(STORE));
				req.onsuccess = () => resolve(req.result as T);
				req.onerror = () => reject(req.error);
			})
	);
}

export function get<T>(key: string): Promise<T | undefined> {
	return run<T | undefined>('readonly', (s) => s.get(key));
}

export function set(key: string, value: unknown): Promise<void> {
	return run<void>('readwrite', (s) => s.put(value, key));
}
