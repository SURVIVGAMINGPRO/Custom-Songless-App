<script lang="ts">
	import Dialog from './Dialog.svelte';

	let {
		open = $bindable(false),
		title,
		message,
		confirm,
		onconfirm
	}: { open?: boolean; title: string; message: string; confirm: string; onconfirm: () => void } = $props();
</script>

<Dialog bind:open {title}>
	<p class="muted">{message}</p>
	{#snippet actions()}
		<!-- svelte-ignore a11y_autofocus -->
		<button class="btn quiet" type="button" autofocus onclick={() => (open = false)}>Cancel</button>
		<button
			class="btn danger"
			type="button"
			onclick={() => {
				open = false;
				onconfirm();
			}}>{confirm}</button
		>
	{/snippet}
</Dialog>
