(() => {
    'use strict';
    const el = id => document.getElementById(id);
    const selected = new Set();
    let roles = [];
    let busy = false;
    const showError = message => {
        el('build-error').textContent = message;
        el('build-error').classList.remove('hidden');
    };
    async function request(url, options = {}) {
        const response = await fetch(url, { ...options, credentials: 'same-origin' });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
        return data;
    }
    function update() {
        el('role-count').textContent = `${selected.size} ausgewählt / ${roles.length} verfügbar`;
        el('create-button').disabled = busy || !selected.size;
    }
    function render() {
        const query = el('role-search').value.trim().toLowerCase();
        const list = el('role-list');
        list.replaceChildren();
        for (const role of roles.filter(r => `${r.displayName} ${r.description || ''} ${r.id}`.toLowerCase().includes(query))) {
            const label = document.createElement('label');
            label.className = 'flex items-start gap-3 rounded-box border border-base-300 p-3 cursor-pointer';
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.className = 'checkbox checkbox-sm mt-1';
            checkbox.checked = selected.has(role.id);
            checkbox.disabled = busy;
            checkbox.addEventListener('change', () => {
                if (checkbox.checked) selected.add(role.id); else selected.delete(role.id);
                update();
            });
            const text = document.createElement('span');
            const name = document.createElement('span');
            name.className = 'block font-medium';
            name.textContent = role.displayName;
            const description = document.createElement('span');
            description.className = 'block text-xs opacity-60';
            description.textContent = role.description || role.id;
            text.append(name, description);
            label.append(checkbox, text);
            list.append(label);
        }
        if (!list.childElementCount) list.textContent = 'Keine passenden Rollen gefunden.';
        update();
    }
    async function loadRoles() {
        el('reload-roles').disabled = true;
        el('role-list').setAttribute('aria-busy', 'true');
        el('build-error').classList.add('hidden');
        try {
            const data = await request('/api/roles');
            roles = Array.isArray(data.roles) ? data.roles : [];
            const available = new Set(roles.map(r => r.id));
            for (const id of selected) if (!available.has(id)) selected.delete(id);
            render();
        } catch (error) {
            roles = []; selected.clear(); render(); showError(error.message);
        } finally {
            el('reload-roles').disabled = false;
            el('role-list').setAttribute('aria-busy', 'false');
        }
    }
    el('role-search').addEventListener('input', render);
    el('reload-roles').addEventListener('click', loadRoles);
    el('relationship-form').addEventListener('submit', async event => {
        event.preventDefault();
        if (busy || !selected.size || !event.target.reportValidity()) return;
        el('build-error').classList.add('hidden');
        el('build-success').classList.add('hidden');
        const body = {
            DisplayName: el('display-name').value.trim(),
            CustomerTenantId: el('tenant-id').value.trim(),
            Duration: `P${Number(el('duration').value)}D`,
            AutoExtendDuration: el('auto-extend').value,
            UnifiedRoles: [...selected].map(id => ({ roleDefinitionId: id }))
        };
        if (!body.DisplayName) return showError('Relationship name is required.');
        if (body.AutoExtendDuration === 'P180D' && selected.has('62e90394-69f5-4237-9190-012177145e10')) {
            return showError('Auto-Extend für Global Administrator deaktivieren.');
        }
        const names = roles.filter(r => selected.has(r.id)).map(r => r.displayName).join(', ');
        if (!window.confirm(`GDAP-Beziehung erstellen?\n\n${body.DisplayName}\nTenant: ${body.CustomerTenantId}\nLaufzeit: ${body.Duration}\nAuto-Extend: ${body.AutoExtendDuration}\nRollen: ${names}`)) return;
        busy = true;
        el('reload-roles').disabled = true;
        el('create-button').textContent = 'Wird erstellt …';
        render();
        try {
            const data = await request('/api/relationship', {
                method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
            });
            el('build-success').textContent = `Beziehung erstellt: ${data.result.displayName} | ID: ${data.result.id} | Status: ${data.result.status || data.status}. Noch nicht automatisch aktiv.`;
            el('build-success').classList.remove('hidden');
            selected.clear();
            el('display-name').value = '';
        } catch (error) {
            showError(`${error.message} Bei unklarem Ergebnis zuerst unter Relationships prüfen, bevor du erneut erstellst.`);
        } finally {
            busy = false;
            el('reload-roles').disabled = false;
            el('create-button').textContent = 'Create GDAP Relationship';
            render();
        }
    });
    loadRoles();
})();
