(() => {
    'use strict';
    const getElement = id => document.getElementById(id);
    const selected = new Set();
    let roles = [];
    let customers = [];
    let busy = false;
    let loadingRoles = true;
    let loadingCustomers = true;
    let draggedRoleId = null;
    const refreshButton = createPageRefresh(() => {
        if (busy || loadingRoles || loadingCustomers) return;
        return Promise.all([loadRoles(), loadCustomers()]);
    });
    const showError = message => {
        getElement('buildError').textContent = message;
        getElement('buildError').classList.remove('hidden');
    };
    async function request(url, options = {}) {
        const response = await fetch(url, { cache: 'no-store', ...options, credentials: 'same-origin' });
        const data = await response.json();
        if (!response.ok) {
            const error = new Error(data.error || `HTTP ${response.status}`);
            error.relationshipCreated = data.relationshipCreated === true;
            error.relationshipId = data.result?.id;
            throw error;
        }
        return data;
    }
    function update() {
        getElement('roleCount').textContent = `${selected.size} ausgewählt / ${roles.length} verfügbar`;
        getElement('createButton').disabled = busy || loadingRoles || !selected.size;
        getElement('relationshipForm').querySelectorAll('input, select').forEach(input => { input.disabled = busy; });
        getElement('customerSearch').disabled = busy || loadingCustomers;
        getElement('customerSelect').disabled = busy || loadingCustomers || !customers.length;
        getElement('reloadCustomers').disabled = busy || loadingCustomers;
        getElement('reloadRoles').disabled = busy || loadingRoles;
        refreshButton.disabled = busy || loadingRoles || loadingCustomers;
        refreshButton.textContent = loadingRoles || loadingCustomers ? 'Wird geladen …' : 'Refresh';
    }
    function render() {
        const query = getElement('roleSearch').value.trim().toLowerCase();
        const availableList = getElement('roleList');
        const selectedList = getElement('selectedRoleList');
        availableList.replaceChildren();
        selectedList.replaceChildren();
        for (const role of roles) {
            const isSelected = selected.has(role.id);
            if (!isSelected && !`${role.displayName} ${role.description || ''} ${role.id}`.toLowerCase().includes(query)) continue;
            const card = document.createElement('div');
            card.className = 'flex items-start justify-between gap-3 rounded-box border border-base-300 bg-base-100 p-3';
            card.setAttribute('role', 'listitem');
            card.draggable = !busy && !loadingRoles;
            card.dataset.roleId = role.id;
            card.addEventListener('dragstart', event => {
                if (busy || loadingRoles) return event.preventDefault();
                draggedRoleId = role.id;
                event.dataTransfer.setData('text/plain', role.id);
                event.dataTransfer.effectAllowed = 'move';
            });
            card.addEventListener('dragend', () => {
                draggedRoleId = null;
                clearDropHighlight();
            });
            const text = document.createElement('span');
            const name = document.createElement('span');
            name.className = 'block font-medium';
            name.textContent = role.displayName;
            const description = document.createElement('span');
            description.className = 'block text-xs opacity-60';
            description.textContent = role.description || role.id;
            text.append(name, description);
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'btn btn-ghost btn-sm';
            button.textContent = isSelected ? 'Entfernen' : 'Hinzufügen';
            button.setAttribute('aria-label', `${role.displayName}: ${button.textContent}`);
            button.disabled = busy || loadingRoles;
            button.addEventListener('click', () => {
                const list = isSelected ? selectedList : availableList;
                const index = [...list.children].indexOf(card);
                setRoleSelected(role.id, !isSelected);
                const next = list.children[Math.min(index, list.children.length - 1)];
                (next?.querySelector('button') || getElement('roleSearch')).focus();
            });
            card.append(text, button);
            (isSelected ? selectedList : availableList).append(card);
        }
        if (!availableList.childElementCount) availableList.textContent = 'Keine passenden Rollen verfügbar.';
        if (!selectedList.childElementCount) selectedList.textContent = 'Rollen hierher ziehen.';
        update();
    }
    function setRoleSelected(id, value) {
        if (busy || loadingRoles || !roles.some(role => role.id === id)) return;
        if (value) selected.add(id); else selected.delete(id);
        render();
    }
    function clearDropHighlight() {
        for (const id of ['roleList', 'selectedRoleList']) getElement(id).classList.remove('ring-2', 'ring-primary');
    }
    for (const id of ['roleList', 'selectedRoleList']) {
        const list = getElement(id);
        list.addEventListener('dragover', event => {
            if (busy || loadingRoles || !draggedRoleId) return;
            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            list.classList.add('ring-2', 'ring-primary');
        });
        list.addEventListener('dragleave', event => {
            if (!list.contains(event.relatedTarget)) clearDropHighlight();
        });
        list.addEventListener('drop', event => {
            event.preventDefault();
            clearDropHighlight();
            if (!draggedRoleId || event.dataTransfer.getData('text/plain') !== draggedRoleId) return;
            setRoleSelected(draggedRoleId, id === 'selectedRoleList');
            draggedRoleId = null;
        });
    }
    function renderCustomers() {
        const query = getElement('customerSearch').value.trim().toLowerCase();
        const select = getElement('customerSelect');
        select.replaceChildren(new Option('Kunden auswählen oder Tenant-ID manuell eingeben', ''));
        for (const customer of customers.filter(c => `${c.displayName} ${c.tenantId}`.toLowerCase().includes(query))) {
            select.add(new Option(`${customer.displayName} (${customer.tenantId})`, customer.tenantId));
        }
        select.value = getElement('tenantId').value.trim();
        if (select.selectedIndex < 0) select.value = '';
        getElement('customerStatus').textContent = `${select.options.length - 1} von ${customers.length} Kunden`;
    }
    async function loadCustomers() {
        loadingCustomers = true;
        update();
        getElement('customerStatus').textContent = 'Kunden werden geladen …';
        try {
            const data = await request('/api/customers');
            if (!Array.isArray(data.customers)) throw new Error('Ungültige Kundenantwort.');
            customers = data.customers;
            renderCustomers();
        } catch (error) {
            customers = [];
            getElement('customerSelect').replaceChildren(new Option('Kunden nicht verfügbar', ''));
            getElement('customerStatus').textContent = `Kunden konnten nicht geladen werden: ${error.message} Tenant-ID manuell eingeben oder erneut laden.`;
        } finally {
            loadingCustomers = false;
            update();
        }
    }
    async function loadRoles() {
        loadingRoles = true;
        render();
        getElement('roleList').setAttribute('aria-busy', 'true');
        getElement('buildError').classList.add('hidden');
        try {
            const data = await request('/api/roles');
            if (!Array.isArray(data.roles)) throw new Error('Ungültige Rollenantwort.');
            roles = data.roles;
            const available = new Set(roles.map(r => r.id));
            for (const id of selected) if (!available.has(id)) selected.delete(id);
            render();
        } catch (error) {
            roles = []; selected.clear(); render(); showError(error.message);
        } finally {
            loadingRoles = false;
            render();
            getElement('roleList').setAttribute('aria-busy', 'false');
        }
    }
    getElement('roleSearch').addEventListener('input', render);
    getElement('customerSearch').addEventListener('input', () => {
        if (!getElement('customerSelect').disabled) renderCustomers();
    });
    getElement('customerSelect').addEventListener('change', () => {
        if (getElement('customerSelect').value) getElement('tenantId').value = getElement('customerSelect').value;
    });
    getElement('tenantId').addEventListener('input', () => {
        getElement('customerSelect').value = getElement('tenantId').value.trim();
        if (getElement('customerSelect').selectedIndex < 0) getElement('customerSelect').value = '';
    });
    getElement('reloadCustomers').addEventListener('click', loadCustomers);
    getElement('reloadRoles').addEventListener('click', loadRoles);
    getElement('relationshipForm').addEventListener('submit', async event => {
        event.preventDefault();
        if (busy || loadingRoles || !selected.size || !event.target.reportValidity()) return;
        getElement('buildError').classList.add('hidden');
        getElement('buildSuccess').classList.add('hidden');
        const body = {
            displayName: getElement('displayName').value.trim(),
            customerTenantId: getElement('tenantId').value.trim(),
            duration: `P${Number(getElement('duration').value)}D`,
            autoExtendDuration: getElement('autoExtend').value,
            unifiedRoles: [...selected].map(id => ({ roleDefinitionId: id }))
        };
        if (!body.displayName) return showError('Relationship name is required.');
        if (body.autoExtendDuration === 'P180D' && selected.has('62e90394-69f5-4237-9190-012177145e10')) {
            return showError('Auto-Extend für Global Administrator deaktivieren.');
        }
        const names = roles.filter(r => selected.has(r.id)).map(r => r.displayName).join(', ');
        if (!window.confirm(`GDAP-Beziehung erstellen und zur Kundenfreigabe einreichen?\n\n${body.displayName}\nTenant: ${body.customerTenantId}\nLaufzeit: ${body.duration}\nAuto-Extend: ${body.autoExtendDuration}\nRollen: ${names}`)) return;
        busy = true;
        getElement('createButton').textContent = 'Wird erstellt …';
        render();
        try {
            const data = await request('/api/relationship', {
                method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
            });
            getElement('buildSuccess').textContent = `Beziehung erstellt und zur Kundenfreigabe eingereicht: ${data.result.displayName} | ID: ${data.result.id}. Die Genehmigung durch den Kunden steht noch aus.`;
            getElement('buildSuccess').classList.remove('hidden');
            selected.clear();
            getElement('displayName').value = '';
        } catch (error) {
            showError(error.relationshipCreated
                ? `Beziehung bereits erstellt (ID: ${error.relationshipId}), aber nicht zur Kundenfreigabe eingereicht: ${error.message} Nicht erneut erstellen; die bestehende Beziehung unter Relationships prüfen.`
                : `${error.message} Bei unklarem Ergebnis zuerst unter Relationships prüfen, bevor du erneut erstellst.`);
        } finally {
            busy = false;
            getElement('createButton').textContent = 'Create GDAP Relationship';
            render();
        }
    });
    loadRoles();
    loadCustomers();
})();