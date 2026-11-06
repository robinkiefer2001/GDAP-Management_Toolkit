// Seite: Relationships – Suche, Filter, Sortierung und Pagination

(() => {
    'use strict';

    const defaultPageSize = 25;
    const searchDelay = 180;
    const dayMs = 86_400_000;

    const collator = new Intl.Collator('de-CH', {
        sensitivity: 'base',
        numeric: true
    });

    const state = {
        rows: [],
        search: '',
        status: '',
        customer: '',
        autoExtend: '',
        expiry: '',
        sort: 'name-asc',
        page: 1,
        pageSize: defaultPageSize
    };

    let searchTimer;

    function text(value) {
        return value == null ? '' : String(value);
    }

    function normalize(value) {
        return text(value)
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase();
    }

    function parseDate(value) {
        if (!value) return null;

        const timestamp = Date.parse(value);
        return Number.isFinite(timestamp) ? timestamp : null;
    }

    function isAutoExtendEnabled(value) {
        // Unterstützt Boolean sowie entsprechende String-Werte.
        return value === true
            || value === 1
            || ['true', '1', 'enabled'].includes(
                text(value).trim().toLowerCase()
            );
    }

    function roleSearchText(role) {
        if (typeof role === 'string') return role;
        if (!role || typeof role !== 'object') return '';

        return [
            role.roleDisplayName,
            role.displayName,
            role.roleName,
            role.name,
            role.roleDefinitionId,
            role.id
        ].filter(Boolean).join(' ');
    }

    function prepareRows() {
        const relationships = Array.isArray(gdapData.relationships)
            ? gdapData.relationships
            : [];

        // Kundennamen pro Tenant nur einmal auflösen.
        const customerNames = new Map();

        state.rows = relationships.map((relationship) => {
            const tenantId = text(relationship.relationshipCustomerId);

            if (!customerNames.has(tenantId)) {
                customerNames.set(
                    tenantId,
                    text(customerNameByTenant(tenantId)) || tenantId || 'Unbekannt'
                );
            }

            const customerName = customerNames.get(tenantId);
            const name = text(relationship.relationshipName) || 'Ohne Namen';
            const status = text(relationship.relationshipStatus).trim();
            const roles = Array.isArray(relationship.relationshipRoles)
                ? relationship.relationshipRoles
                : [];

            return {
                relationship,
                name,
                tenantId,
                customerName,
                status,
                roles,
                expiresAt: parseDate(
                    relationship.relationshipExpirationDate
                ),
                autoExtend: isAutoExtendEnabled(
                    relationship.relationshipAutoExtend
                ),
                searchText: normalize([
                    name,
                    customerName,
                    tenantId,
                    relationship.relationshipId,
                    status,
                    ...roles.map(roleSearchText)
                ].join(' '))
            };
        });
    }

    function populateFilters() {
        const previousStatus = getElement('filterRelationshipStatus').value;
        const previousCustomer = getElement('filterRelationshipCustomer').value;
        const statuses = [...new Set(
            state.rows.map((row) => row.status).filter(Boolean)
        )].sort(collator.compare);

        getElement('filterRelationshipStatus').innerHTML = [
            '<option value="">Alle Status</option>',
            ...statuses.map((status) => `
                <option value="${escapeHtml(status)}">
                    ${escapeHtml(status)}
                </option>
            `)
        ].join('');

        const customers = new Map();

        for (const row of state.rows) {
            if (row.tenantId) {
                customers.set(row.tenantId, row.customerName);
            }
        }

        getElement('filterRelationshipCustomer').innerHTML = [
            '<option value="">Alle Kunden</option>',
            ...[...customers.entries()]
                .sort((a, b) => collator.compare(a[1], b[1]))
                .map(([tenantId, name]) => `
                    <option value="${escapeHtml(tenantId)}">
                        ${escapeHtml(name)}
                    </option>
                `)
        ].join('');
        getElement('filterRelationshipStatus').value = statuses.includes(previousStatus) ? previousStatus : '';
        getElement('filterRelationshipCustomer').value = customers.has(previousCustomer) ? previousCustomer : '';
    }

    function matchesExpiry(row, now) {
        if (!state.expiry) return true;

        if (state.expiry === 'unknown') {
            return row.expiresAt === null;
        }

        if (row.expiresAt === null) return false;

        if (state.expiry === 'expired') {
            return row.expiresAt <= now;
        }

        if (state.expiry === 'future') {
            return row.expiresAt > now;
        }

        const days = Number(state.expiry);

        return row.expiresAt > now
            && row.expiresAt <= now + days * dayMs;
    }

    function compareRows(a, b) {
        let result = 0;

        switch (state.sort) {
            case 'name-desc':
                result = collator.compare(b.name, a.name);
                break;

            case 'customer-asc':
                result = collator.compare(a.customerName, b.customerName);
                break;

            case 'expiry-asc':
            case 'expiry-desc':
                // Unbekannte Ablaufdaten immer am Ende.
                if (a.expiresAt === null && b.expiresAt !== null) return 1;
                if (a.expiresAt !== null && b.expiresAt === null) return -1;

                if (a.expiresAt !== null && b.expiresAt !== null) {
                    result = state.sort === 'expiry-asc'
                        ? a.expiresAt - b.expiresAt
                        : b.expiresAt - a.expiresAt;
                }
                break;

            case 'roles-desc':
                result = b.roles.length - a.roles.length;
                break;

            default:
                result = collator.compare(a.name, b.name);
        }

        return result
            || collator.compare(a.name, b.name)
            || collator.compare(a.tenantId, b.tenantId);
    }

    function renderRow(row) {
        const r = row.relationship;

        return `
            <details class="collapse collapse-arrow bg-base-100 border border-base-300">
                <summary class="collapse-title font-medium">
                    <div class="flex flex-wrap items-center gap-2 pr-4">
                        <span class="min-w-0 break-words">
                            ${escapeHtml(row.name)}
                        </span>

                        ${statusBadge(row.status)}

                        <span class="badge badge-ghost badge-sm">
                            ${row.roles.length} Rollen
                        </span>

                        <span class="ml-auto text-xs font-normal opacity-60">
                            Ablauf:
                            ${formatDate(r.relationshipExpirationDate)}
                        </span>
                    </div>

                    <div class="mt-1 text-xs font-normal opacity-60 break-words">
                        ${escapeHtml(row.customerName)}
                    </div>
                </summary>

                <div class="collapse-content space-y-3">
                    <div class="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
                        <div>
                            <span class="opacity-60">Kunde:</span>
                            ${escapeHtml(row.customerName)}
                        </div>

                        <div>
                            <span class="opacity-60">Tenant-ID:</span>
                            <span class="font-mono text-xs break-all">
                                ${escapeHtml(row.tenantId) || '–'}
                            </span>
                        </div>

                        <div>
                            <span class="opacity-60">Start:</span>
                            ${formatDate(r.relationshipStartDate)}
                        </div>

                        <div>
                            <span class="opacity-60">Ablauf:</span>
                            ${formatDate(r.relationshipExpirationDate)}
                        </div>

                        <div>
                            <span class="opacity-60">Auto-Extend:</span>
                            <span class="badge badge-sm ${
                                row.autoExtend
                                    ? 'badge-success'
                                    : 'badge-warning'
                            }">
                                ${row.autoExtend ? 'aktiviert' : 'deaktiviert'}
                            </span>
                        </div>

                        <div>
                            <span class="opacity-60">Rollen:</span>
                            ${row.roles.length}
                        </div>
                    </div>

                    <div class="flex flex-wrap gap-1">
                        ${row.roles.length
                            ? roleBadges(row.roles)
                            : '<span class="text-sm opacity-60">Keine Rollen vorhanden.</span>'
                        }
                    </div>
                </div>
            </details>
        `;
    }

    function renderRelationships() {
        const now = Date.now();
        const tokens = normalize(state.search).trim().split(/\s+/).filter(Boolean);

        const filtered = state.rows.filter((row) => {
            if (!tokens.every((token) => row.searchText.includes(token))) {
                return false;
            }

            if (state.status && row.status !== state.status) return false;
            if (state.customer && row.tenantId !== state.customer) return false;

            if (
                state.autoExtend
                && row.autoExtend !== (state.autoExtend === 'enabled')
            ) {
                return false;
            }

            return matchesExpiry(row, now);
        });

        filtered.sort(compareRows);

        const total = filtered.length;
        const pages = Math.max(1, Math.ceil(total / state.pageSize));

        state.page = Math.min(Math.max(1, state.page), pages);

        const start = (state.page - 1) * state.pageSize;
        const visible = filtered.slice(start, start + state.pageSize);

        getElement('listRelationships').innerHTML = visible.length
            ? visible.map(renderRow).join('')
            : `
                <div class="alert" role="status">
                    <span>
                        ${state.rows.length
                            ? 'Keine Relationships entsprechen den Such- und Filterkriterien.'
                            : 'Keine Relationships vorhanden.'
                        }
                    </span>
                </div>
            `;

        getElement('relationshipsCount').textContent =
            `${total} von ${state.rows.length} Relationships`;

        getElement('relationshipsRange').textContent = total
            ? `${start + 1}–${Math.min(start + state.pageSize, total)} von ${total}`
            : '0 Treffer';

        getElement('relationshipsPage').textContent =
            `Seite ${state.page} von ${pages}`;

        getElement('relationshipsPrev').disabled = state.page <= 1;
        getElement('relationshipsNext').disabled = state.page >= pages;
    }

    function readControls() {
        state.search = getElement('searchRelationships').value;
        state.status = getElement('filterRelationshipStatus').value;
        state.customer = getElement('filterRelationshipCustomer').value;
        state.autoExtend = getElement('filterRelationshipAutoextend').value;
        state.expiry = getElement('filterRelationshipExpiry').value;
        state.sort = getElement('sortRelationships').value;
        state.pageSize = Number(getElement('relationshipsPageSize').value);
    }

    function applyControls() {
        clearTimeout(searchTimer);
        readControls();
        state.page = 1;
        renderRelationships();
    }

    function resetControls() {
        getElement('searchRelationships').value = '';
        getElement('filterRelationshipStatus').value = '';
        getElement('filterRelationshipCustomer').value = '';
        getElement('filterRelationshipAutoextend').value = '';
        getElement('filterRelationshipExpiry').value = '';
        getElement('sortRelationships').value = 'name-asc';
        getElement('relationshipsPageSize').value = String(defaultPageSize);

        applyControls();
    }

    document.addEventListener('DOMContentLoaded', () => {
        // Vorbelegte Suche, z. B. aus der Manage-Übersicht (?search=…).
        const presetSearch =
            new URLSearchParams(location.search).get('search');

        if (presetSearch) {
            getElement('searchRelationships').value = presetSearch;
        }

        getElement('searchRelationships').addEventListener('input', () => {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(applyControls, searchDelay);
        });

        [
            'filterRelationshipStatus',
            'filterRelationshipCustomer',
            'filterRelationshipAutoextend',
            'filterRelationshipExpiry',
            'sortRelationships',
            'relationshipsPageSize'
        ].forEach((id) => {
            getElement(id).addEventListener('change', applyControls);
        });

        getElement('relationshipsReset').addEventListener('click', resetControls);

        getElement('relationshipsPrev').addEventListener('click', () => {
            state.page -= 1;
            renderRelationships();
        });

        getElement('relationshipsNext').addEventListener('click', () => {
            state.page += 1;
            renderRelationships();
        });

        initPage(() => {
            prepareRows();
            populateFilters();
            readControls();
            renderRelationships();
        });
    });
})();