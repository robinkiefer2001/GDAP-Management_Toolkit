// Seite: Manage – Übersicht offener GDAP-Aufgaben und Create Request
// (ehemals Build: Kundenauswahl, Rollen-Drag-and-drop, Erstellung).

(() => {
    'use strict';

    // ---------- Zustand ----------

    const selected = new Set();

    let roles = [];
    let knownCustomers = [];
    let overviewRows = [];
    let busy = false;
    let loadingRoles = true;
    let loadingCustomers = true;
    let loadingOverview = false;
    let overviewLoaded = false;
    let draggedRoleId = null;

    const CACHE_TTL = 30 * 60 * 1000;

    const CACHE_KEYS = {
        roles: 'gdap:roles:v1',
        customers: 'gdap:customers:v1'
    };

    function readCache(key) {
        try {
            const cached = JSON.parse(sessionStorage.getItem(key));

            if (
                !cached ||
                !Array.isArray(cached.items) ||
                !Number.isFinite(cached.savedAt) ||
                Date.now() - cached.savedAt >= CACHE_TTL
            ) {
                return null;
            }

            return cached.items;
        } catch {
            return null;
        }
    }

    function writeCache(key, items) {
        try {
            sessionStorage.setItem(key, JSON.stringify({
                savedAt: Date.now(),
                items
            }));
        } catch {
            // Continue normally if browser storage is unavailable.
        }
    }

    const refreshButton = createPageRefresh(() => {
        if (busy || loadingRoles || loadingCustomers || loadingOverview) {
            return;
        }

        return Promise.all([
            loadOverview(true),
            loadRoles({ force: true }),
            loadCustomers({ force: true })
        ]);
    });

    async function request(url, options = {}) {
        const response = await fetch(url, {
            cache: 'no-store',
            ...options,
            credentials: 'same-origin'
        });

        const data = await response.json();

        if (!response.ok) {
            const error = new Error(
                data.error || `HTTP ${response.status}`
            );

            error.relationshipCreated = data.relationshipCreated === true;
            error.relationshipId = data.result?.id;

            throw error;
        }

        return data;
    }

    function update() {
        getElement('roleCount').textContent =
            `${selected.size} ausgewählt / ${roles.length} verfügbar`;

        getElement('createButton').disabled =
            busy || loadingRoles || !selected.size;

        getElement('relationshipForm')
            .querySelectorAll('input, select')
            .forEach(input => {
                input.disabled = busy;
            });

        getElement('customerSearch').disabled =
            busy || loadingCustomers;

        getElement('customerSelect').disabled =
            busy || loadingCustomers || !knownCustomers.length;

        getElement('reloadCustomers').disabled =
            busy || loadingCustomers;

        getElement('reloadRoles').disabled =
            busy || loadingRoles;

        const loadingAnything =
            loadingRoles || loadingCustomers || loadingOverview;

        refreshButton.disabled = busy || loadingAnything;

        refreshButton.textContent = loadingAnything
            ? 'Wird geladen …'
            : 'Refresh';
    }

    // ---------- Seitennavigation ----------

    const panelButtons = [
        ...document.querySelectorAll('.manage-sidebar [data-panel]')
    ];

    const panels = {
        overview: getElement('overviewPanel'),
        createRequest: getElement('createRequestPanel')
    };

    function showPanel(name) {
        for (const [key, panel] of Object.entries(panels)) {
            panel.classList.toggle('hidden', key !== name);
        }

        for (const button of panelButtons) {
            if (button.dataset.panel === name) {
                button.setAttribute('aria-current', 'page');
            } else {
                button.removeAttribute('aria-current');
            }
        }
    }

    for (const button of panelButtons) {
        button.addEventListener(
            'click',
            () => showPanel(button.dataset.panel)
        );
    }

    // ---------- Übersicht ----------

    const statusMeta = {
        approvalPending: {
            label: 'Approval Pending',
            badgeClass: 'badge-warning',
            nextStep: 'In Relationships prüfen',
            nextStepTitle:
                'Kundenfreigabe ausstehend – Beziehung unter ' +
                'Relationships öffnen.'
        },
        notCreated: {
            label: 'Noch nicht erstellt',
            badgeClass: 'badge-info',
            nextStep: 'Anfrage erstellen',
            nextStepTitle:
                'Create Request mit diesem Kunden vorausfüllen.'
        }
    };

    // Status, bei denen kein Handlungsbedarf "Noch nicht erstellt" besteht.
    const openStatuses = new Set([
        'active', 'activating', 'approvalpending',
        'approved', 'created', 'expiring'
    ]);

    function normalizeSearch(value) {
        return String(value ?? '').trim().toLowerCase();
    }

    function buildOverviewRows() {
        const customers = Array.isArray(gdapData?.customers)
            ? gdapData.customers
            : [];

        overviewRows = [];

        for (const customer of customers) {
            const customerName =
                customer.customerName || customer.customerTenantId || '—';

            const tenantId = customer.customerTenantId || '';

            const relationships =
                Array.isArray(customer.customerGdapRelationships)
                    ? customer.customerGdapRelationships
                    : [];

            let hasOpenRelationship = false;

            for (const relationship of relationships) {
                const status = normalizeSearch(
                    relationship.relationshipStatus
                );

                if (openStatuses.has(status)) {
                    hasOpenRelationship = true;
                }

                if (status === 'approvalpending') {
                    overviewRows.push({
                        type: 'approvalPending',
                        customerName,
                        tenantId,
                        relationshipName:
                            relationship.relationshipName || 'Ohne Namen'
                    });
                }
            }

            if (!hasOpenRelationship) {
                overviewRows.push({
                    type: 'notCreated',
                    customerName,
                    tenantId,
                    relationshipName: relationships.length
                        ? 'Keine aktive Beziehung'
                        : '—'
                });
            }
        }

        for (const row of overviewRows) {
            row.searchText = normalizeSearch(
                `${row.customerName} ${row.tenantId} ${row.relationshipName}`
            );
        }
    }

    // Create Request mit dem Kunden aus der Übersicht vorbefüllen.
    function openCreateRequest(tenantId) {
        showPanel('createRequest');

        if (tenantId && !busy) {
            getElement('tenantId').value = tenantId;

            const select = getElement('customerSelect');
            select.value = tenantId;

            if (select.selectedIndex < 0) {
                select.value = '';
            }
        }

        getElement('displayName').focus();
    }

    function runRowAction(row) {
        if (row.type === 'notCreated') {
            openCreateRequest(row.tenantId);
            return;
        }

        // Beziehung mit ausstehender Freigabe unter Relationships öffnen.
        const query = row.relationshipName !== 'Ohne Namen'
            ? row.relationshipName
            : row.tenantId;

        location.href =
            `relationships.html?search=${encodeURIComponent(query)}`;
    }

    function emptyStateRow(title, description) {
        const cell = document.createElement('td');
        cell.colSpan = 4;

        const wrapper = document.createElement('div');
        wrapper.className = 'manage-empty-state';

        const heading = document.createElement('p');
        heading.className = 'font-medium';
        heading.textContent = title;

        const text = document.createElement('p');
        text.className = 'mt-1 text-sm text-base-content/60';
        text.textContent = description;

        wrapper.append(heading, text);
        cell.append(wrapper);

        const row = document.createElement('tr');
        row.append(cell);

        return row;
    }

    function renderOverview() {
        const pendingCount = overviewRows
            .filter(row => row.type === 'approvalPending').length;

        const notCreatedCount = overviewRows
            .filter(row => row.type === 'notCreated').length;

        const affectedCount = new Set(
            overviewRows.map(row => row.tenantId)
        ).size;

        getElement('pendingApprovalCount').textContent =
            overviewLoaded ? pendingCount : '—';

        getElement('notCreatedCount').textContent =
            overviewLoaded ? notCreatedCount : '—';

        getElement('affectedCustomerCount').textContent =
            overviewLoaded ? affectedCount : '—';

        const query = normalizeSearch(getElement('manageSearch').value);
        const statusFilter = getElement('manageStatusFilter').value;

        const visible = overviewRows.filter(row =>
            (statusFilter === 'all' || row.type === statusFilter) &&
            (!query || row.searchText.includes(query))
        );

        getElement('manageCustomerCount').textContent =
            `${new Set(visible.map(row => row.tenantId)).size} Kunden`;

        const body = getElement('manageCustomerRows');
        body.replaceChildren();

        if (!visible.length) {
            if (!overviewLoaded) {
                body.append(emptyStateRow(
                    'Noch keine Daten geladen',
                    'Hier erscheinen die Kunden mit ausstehender Freigabe ' +
                    'oder noch nicht erstellter Anfrage.'
                ));
            } else if (overviewRows.length) {
                body.append(emptyStateRow(
                    'Keine Treffer',
                    'Suche oder Statusfilter anpassen, um Einträge zu sehen.'
                ));
            } else {
                body.append(emptyStateRow(
                    'Keine offenen Aufgaben',
                    'Alle Kunden haben eine aktive oder laufende ' +
                    'GDAP-Beziehung.'
                ));
            }

            return;
        }

        const template = getElement('manageCustomerRowTemplate');

        for (const row of visible) {
            const meta = statusMeta[row.type];
            const fragment = template.content.cloneNode(true);

            fragment.querySelector('[data-field="customerName"]')
                .textContent = row.customerName;

            fragment.querySelector('[data-field="tenantId"]')
                .textContent = row.tenantId || '—';

            fragment.querySelector('[data-field="relationshipName"]')
                .textContent = row.relationshipName;

            const status = fragment.querySelector('[data-field="status"]');
            status.textContent = meta.label;
            status.classList.add(meta.badgeClass);

            const action = fragment.querySelector('[data-field="nextStep"]');
            action.textContent = meta.nextStep;
            action.title = meta.nextStepTitle;

            action.addEventListener('click', event => {
                event.stopPropagation();
                runRowAction(row);
            });

            const tableRow = fragment.querySelector('tr');
            tableRow.dataset.action = row.type;
            tableRow.title = meta.nextStepTitle;
            tableRow.addEventListener('click', () => runRowAction(row));

            body.append(fragment);
        }
    }

    async function loadOverview(forceRefresh = false) {
        if (loadingOverview) return;

        loadingOverview = true;
        getElement('manageError').classList.add('hidden');

        getElement('manageDataStatus').textContent =
            'Daten werden geladen …';

        update();

        try {
            await loadGdapData(forceRefresh);
            buildOverviewRows();
            overviewLoaded = true;

            getElement('manageSearch').disabled = false;
            getElement('manageStatusFilter').disabled = false;

            getElement('manageDataStatus').textContent =
                `Stand: ${new Date().toLocaleString('de-CH')} – ` +
                `${overviewRows.length} offene Einträge`;
        } catch (error) {
            getElement('manageError').textContent =
                'Daten konnten nicht geladen werden: ' + error.message +
                ' — Wurde der Server in einer Session mit aktiver ' +
                'Graph-Verbindung (Connect-MgGraph) gestartet?' +
                (overviewLoaded
                    ? ' Angezeigte Daten sind möglicherweise veraltet.'
                    : '');

            getElement('manageError').classList.remove('hidden');

            getElement('manageDataStatus').textContent =
                'Daten konnten nicht geladen werden';
        } finally {
            loadingOverview = false;
            renderOverview();
            update();
        }
    }

    getElement('manageSearch').addEventListener('input', renderOverview);

    getElement('manageStatusFilter')
        .addEventListener('change', renderOverview);

    // ---------- Create Request ----------

    const showError = message => {
        getElement('createError').textContent = message;
        getElement('createError').classList.remove('hidden');
    };

    function render() {
        const query = normalizeSearch(getElement('roleSearch').value);

        const availableList = getElement('roleList');
        const selectedList = getElement('selectedRoleList');

        availableList.replaceChildren();
        selectedList.replaceChildren();

        for (const role of roles) {
            const isSelected = selected.has(role.id);

            const searchable =
                `${role.displayName} ${role.description || ''} ${role.id}`
                    .toLowerCase();

            if (!isSelected && !searchable.includes(query)) continue;

            const card = document.createElement('div');

            card.className =
                'flex items-start justify-between gap-3 rounded-box ' +
                'border border-base-300 bg-base-100 p-3';

            card.setAttribute('role', 'listitem');
            card.draggable = !busy && !loadingRoles;
            card.dataset.roleId = role.id;

            card.addEventListener('dragstart', event => {
                if (busy || loadingRoles) {
                    event.preventDefault();
                    return;
                }

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
            button.className = 'btn btn-outline btn-sm';
            button.textContent = isSelected ? 'Entfernen' : 'Hinzufügen';

            button.setAttribute(
                'aria-label',
                `${role.displayName}: ${button.textContent}`
            );

            button.disabled = busy || loadingRoles;

            button.addEventListener('click', () => {
                const list = isSelected ? selectedList : availableList;
                const index = [...list.children].indexOf(card);

                setRoleSelected(role.id, !isSelected);

                const next = list.children[
                    Math.min(index, list.children.length - 1)
                ];

                (
                    next?.querySelector('button') ||
                    getElement('roleSearch')
                ).focus();
            });

            card.append(text, button);
            (isSelected ? selectedList : availableList).append(card);
        }

        if (!availableList.childElementCount) {
            availableList.textContent = 'Keine passenden Rollen verfügbar.';
        }

        if (!selectedList.childElementCount) {
            selectedList.textContent = 'Rollen hierher ziehen.';
        }

        update();
    }

    function setRoleSelected(id, value) {
        if (
            busy ||
            loadingRoles ||
            !roles.some(role => role.id === id)
        ) {
            return;
        }

        if (value) {
            selected.add(id);
        } else {
            selected.delete(id);
        }

        render();
    }

    function clearDropHighlight() {
        for (const id of ['roleList', 'selectedRoleList']) {
            getElement(id).classList.remove('ring-2', 'ring-neutral');
        }
    }

    for (const id of ['roleList', 'selectedRoleList']) {
        const list = getElement(id);

        list.addEventListener('dragover', event => {
            if (busy || loadingRoles || !draggedRoleId) return;

            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            list.classList.add('ring-2', 'ring-neutral');
        });

        list.addEventListener('dragleave', event => {
            if (!list.contains(event.relatedTarget)) {
                clearDropHighlight();
            }
        });

        list.addEventListener('drop', event => {
            event.preventDefault();
            clearDropHighlight();

            if (
                !draggedRoleId ||
                event.dataTransfer.getData('text/plain') !== draggedRoleId
            ) {
                return;
            }

            setRoleSelected(draggedRoleId, id === 'selectedRoleList');
            draggedRoleId = null;
        });
    }

    function renderCustomers() {
        const query = normalizeSearch(getElement('customerSearch').value);

        const select = getElement('customerSelect');

        select.replaceChildren(
            new Option(
                'Kunden auswählen oder Tenant-ID manuell eingeben',
                ''
            )
        );

        const matches = knownCustomers.filter(customer =>
            `${customer.displayName} ${customer.tenantId}`
                .toLowerCase()
                .includes(query)
        );

        for (const customer of matches) {
            select.add(new Option(
                `${customer.displayName} (${customer.tenantId})`,
                customer.tenantId
            ));
        }

        select.value = getElement('tenantId').value.trim();

        if (select.selectedIndex < 0) {
            select.value = '';
        }

        getElement('customerStatus').textContent =
            `${matches.length} von ${knownCustomers.length} Kunden`;
    }

    async function loadCustomers({ force = false } = {}) {
        loadingCustomers = true;
        update();

        getElement('customerStatus').textContent =
            'Kunden werden geladen …';

        try {
            const cachedCustomers = force
                ? null
                : readCache(CACHE_KEYS.customers);

            if (cachedCustomers !== null) {
                knownCustomers = cachedCustomers;
            } else {
                const data = await request('/api/customers');

                if (!Array.isArray(data.customers)) {
                    throw new Error('Ungültige Kundenantwort.');
                }

                knownCustomers = data.customers;
                writeCache(CACHE_KEYS.customers, knownCustomers);
            }

            renderCustomers();
        } catch (error) {
            knownCustomers = [];

            getElement('customerSelect').replaceChildren(
                new Option('Kunden nicht verfügbar', '')
            );

            getElement('customerStatus').textContent =
                `Kunden konnten nicht geladen werden: ${error.message} ` +
                'Tenant-ID manuell eingeben oder erneut laden.';
        } finally {
            loadingCustomers = false;
            update();
        }
    }

    async function loadRoles({ force = false } = {}) {
        loadingRoles = true;
        render();

        getElement('roleList').setAttribute('aria-busy', 'true');
        getElement('createError').classList.add('hidden');

        try {
            const cachedRoles = force
                ? null
                : readCache(CACHE_KEYS.roles);

            if (cachedRoles !== null) {
                roles = cachedRoles;
            } else {
                const data = await request('/api/roles');

                if (!Array.isArray(data.roles)) {
                    throw new Error('Ungültige Rollenantwort.');
                }

                roles = data.roles;
                writeCache(CACHE_KEYS.roles, roles);
            }

            const available = new Set(roles.map(role => role.id));

            for (const id of selected) {
                if (!available.has(id)) {
                    selected.delete(id);
                }
            }
        } catch (error) {
            roles = [];
            selected.clear();
            showError(error.message);
        } finally {
            loadingRoles = false;
            render();

            getElement('roleList').setAttribute('aria-busy', 'false');
        }
    }

    getElement('roleSearch').addEventListener('input', render);

    getElement('customerSearch').addEventListener('input', () => {
        if (!getElement('customerSelect').disabled) {
            renderCustomers();
        }
    });

    getElement('customerSelect').addEventListener('change', () => {
        const value = getElement('customerSelect').value;

        if (value) {
            getElement('tenantId').value = value;
        }
    });

    getElement('tenantId').addEventListener('input', () => {
        const select = getElement('customerSelect');

        select.value = getElement('tenantId').value.trim();

        if (select.selectedIndex < 0) {
            select.value = '';
        }
    });

    getElement('reloadCustomers').addEventListener('click', () => {
        if (busy || loadingCustomers) return;

        void loadCustomers({ force: true });
    });

    getElement('reloadRoles').addEventListener('click', () => {
        if (busy || loadingRoles) return;

        void loadRoles({ force: true });
    });

    getElement('relationshipForm').addEventListener('submit', async event => {
        event.preventDefault();

        if (
            busy ||
            loadingRoles ||
            !selected.size ||
            !event.target.reportValidity()
        ) {
            return;
        }

        getElement('createError').classList.add('hidden');
        getElement('createSuccess').classList.add('hidden');

        const body = {
            displayName: getElement('displayName').value.trim(),
            customerTenantId: getElement('tenantId').value.trim(),
            duration: `P${Number(getElement('duration').value)}D`,
            autoExtendDuration: getElement('autoExtend').value,
            unifiedRoles: [...selected].map(id => ({
                roleDefinitionId: id
            }))
        };

        if (!body.displayName) {
            return showError('Relationship name is required.');
        }

        if (
            body.autoExtendDuration === 'P180D' &&
            selected.has('62e90394-69f5-4237-9190-012177145e10')
        ) {
            return showError(
                'Auto-Extend für Global Administrator deaktivieren.'
            );
        }

        const names = roles
            .filter(role => selected.has(role.id))
            .map(role => role.displayName)
            .join(', ');

        const confirmed = window.confirm(
            'GDAP-Beziehung erstellen und zur Kundenfreigabe einreichen?\n\n' +
            `${body.displayName}\n` +
            `Tenant: ${body.customerTenantId}\n` +
            `Laufzeit: ${body.duration}\n` +
            `Auto-Extend: ${body.autoExtendDuration}\n` +
            `Rollen: ${names}`
        );

        if (!confirmed) return;

        busy = true;
        getElement('createButton').textContent = 'Wird erstellt …';
        render();

        try {
            const data = await request('/api/relationship', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(body)
            });

            getElement('createSuccess').textContent =
                'Beziehung erstellt und zur Kundenfreigabe eingereicht: ' +
                `${data.result.displayName} | ID: ${data.result.id}. ` +
                'Die Genehmigung durch den Kunden steht noch aus.';

            getElement('createSuccess').classList.remove('hidden');

            selected.clear();
            getElement('displayName').value = '';

            // Übersicht aktualisieren, damit die neue Anfrage erscheint.
            void loadOverview(true);
        } catch (error) {
            showError(
                error.relationshipCreated
                    ? 'Beziehung bereits erstellt ' +
                      `(ID: ${error.relationshipId}), aber nicht zur ` +
                      `Kundenfreigabe eingereicht: ${error.message} ` +
                      'Nicht erneut erstellen; die bestehende Beziehung ' +
                      'unter Relationships prüfen.'
                    : `${error.message} Bei unklarem Ergebnis zuerst ` +
                      'unter Relationships prüfen, bevor du erneut erstellst.'
            );
        } finally {
            busy = false;

            getElement('createButton').textContent =
                'Create GDAP Relationship';

            render();
        }
    });

    // ---------- Start ----------

    void loadOverview();
    void loadRoles();
    void loadCustomers();
})();
