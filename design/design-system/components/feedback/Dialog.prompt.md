Modal on elev-3. Positioned absolute to its nearest positioned ancestor.

```jsx
<Dialog title="Delete vault?" icon="trash-2" onClose={close}
  actions={<><Button variant="ghost">Cancel</Button><Button variant="danger">Delete</Button></>}>
  Sealed documents are destroyed with your key. This can't be undone.
</Dialog>
```
