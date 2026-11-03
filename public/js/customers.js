// Seite: Customers
// Filter und Darstellung arbeiten ausschliesslich mit gdapData.

function normalizeText(value) {
    return String(value ?? '').trim().toLocaleLowerCase('de-CH');
}


// Aktuelle Eingaben aus den HTML-Elementen lesen.
function readCustomerFilters() {
    return {
        customerSearch: normalizeText($('search-customers').value),
        relationshipSearch: normalizeText($('search-relationships').value),
        status: $('filter-status').value,
        autoExtend: $('filter-auto-extend').value,
        relationshipPresence: $('filter-presence').value,
        sort: $('sort-customers').value
    };
}


// Prüfen, ob eine einzelne Beziehung zu allen Beziehungsfiltern passt.
function relationshipMatchesFilters(relationship, filters) {
    const searchText = normalizeText(
        `${relationship.relationshipName ?? ''} ${relationship.relationshipId ?? ''}`
    );

    if (
        filters.relationshipSearch !== '' &&
        !searchText.includes(filters.relationshipSearch)
    ) {
        return false;
    }

    if (
        filters.status !== '' &&
        normalizeText(relationship.relationshipStatus) !== filters.status
    ) {
        return false;
    }

    if (
        filters.autoExtend === 'enabled' &&
        relationship.relationshipAutoExtend !== true
    ) {
        return false;
    }

    if (
        filters.autoExtend === 'disabled' &&
        relationship.relationshipAutoExtend !== false
    ) {
        return false;
    }

    return true;
}


function autoExtendBadge(value) {
    if (value === true) {
        return '<span class="badge badge-success badge-sm">aktiviert</span>';
    }

    if (value === false) {
        return '<span class="badge badge-warning badge-sm">deaktiviert</span>';
    }

    return '<span class="badge badge-ghost badge-sm">unbekannt</span>';
}


// Tabelle innerhalb eines aufgeklappten Kunden.
function relationshipTable(relationships) {
    if (relationships.length === 0) {
        return `
            <p class="py-3 text-sm opacity-60">
                Keine GDAP-Beziehungen vorhanden.
            </p>
        `;
    }

    const rows = relationships.map((relationship) => {
        const roles = relationship.relationshipRoles ?? [];

        return `
            <tr>
                <td class="min-w-64 align-top">
                    <details>
                        <summary class="cursor-pointer font-medium">
                            ${escapeHtml(relationship.relationshipName || 'Ohne Namen')}
                        </summary>

                        <div class="mt-3 space-y-3">
                            <div>
                                <div class="text-xs opacity-60">
                                    Beziehungs-ID
                                </div>

                                <div class="break-all font-mono text-xs">
                                    ${escapeHtml(relationship.relationshipId || '—')}
                                </div>
                            </div>

                            <div>
                                <div class="mb-2 text-xs opacity-60">
                                    Rollen: ${roles.length}
                                </div>

                                <div class="flex flex-wrap gap-1">
                                    ${roleBadges(roles)}
                                </div>
                            </div>
                        </div>
                    </details>
                </td>

                <td class="align-top">
                    ${statusBadge(relationship.relationshipStatus)}
                </td>

                <td class="align-top">
                    ${autoExtendBadge(relationship.relationshipAutoExtend)}
                </td>

                <td class="whitespace-nowrap align-top">
                    ${formatDate(relationship.relationshipStartDate)}
                </td>

                <td class="whitespace-nowrap align-top">
                    ${formatDate(relationship.relationshipExpirationDate)}
                </td>
            </tr>
        `;
    }).join('');

    return `
        <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
                <thead>
                    <tr>
                        <th scope="col">Beziehung / Details</th>
                        <th scope="col">Status</th>
                        <th scope="col">Auto-Extend</th>
                        <th scope="col">Start</th>
                        <th scope="col">Ablauf</th>
                    </tr>
                </thead>

                <tbody>${rows}</tbody>
            </table>
        </div>
    `;
}


// Vorhandene Daten filtern und für die Darstellung vorbereiten.
function selectCustomers(filters) {
    const customers = gdapData.customers ?? [];

    const hasRelationshipFilter =
        filters.relationshipSearch !== '' ||
        filters.status !== '' ||
        filters.autoExtend !== '';

    const results = [];

    for (const customer of customers) {
        const customerSearchText = normalizeText(
            `${customer.customerName ?? ''} ${customer.customerTenantId ?? ''}`
        );

        if (
            filters.customerSearch !== '' &&
            !customerSearchText.includes(filters.customerSearch)
        ) {
            continue;
        }

        const allRelationships = customer.customerGdapRelationships ?? [];

        if (
            filters.relationshipPresence === 'with' &&
            allRelationships.length === 0
        ) {
            continue;
        }

        if (
            filters.relationshipPresence === 'without' &&
            allRelationships.length > 0
        ) {
            continue;
        }

        const matchingRelationships = allRelationships.filter(
            (relationship) => relationshipMatchesFilters(relationship, filters)
        );

        // Sobald Beziehungsfilter gesetzt sind, braucht der Kunde
        // mindestens eine dazu passende Beziehung.
        if (hasRelationshipFilter && matchingRelationships.length === 0) {
            continue;
        }

        results.push({
            customer: customer,
            allRelationships: allRelationships,
            matchingRelationships: matchingRelationships
        });
    }

    results.sort((a, b) => {
        const nameComparison = (a.customer.customerName ?? '')
            .localeCompare(
                b.customer.customerName ?? '',
                'de-CH',
                { sensitivity: 'base', numeric: true }
            );

        if (filters.sort === 'name-desc') {
            return -nameComparison;
        }

        if (filters.sort === 'relationships-desc') {
            const countComparison =
                b.matchingRelationships.length -
                a.matchingRelationships.length;

            return countComparison || nameComparison;
        }

        return nameComparison;
    });

    return results;
}


// Ergebnis ins HTML schreiben.
function renderCustomers() {
    const filters = readCustomerFilters();
    const results = selectCustomers(filters);

    const totalCustomers = (gdapData.customers ?? []).length;

    const relationshipCount = results.reduce(
        (sum, result) => sum + result.matchingRelationships.length,
        0
    );

    $('customer-results').textContent =
        `${results.length} von ${totalCustomers} Kunden · ` +
        `${relationshipCount} passende Beziehungen`;

    if (results.length === 0) {
        $('list-customers').innerHTML = results.map((result) => {
            const customer = result.customer;
            const allCount = result.allRelationships.length;
            const matchingCount = result.matchingRelationships.length;

            return `
        <details class="collapse collapse-arrow bg-base-100 border border-base-300">

            <summary class="collapse-title">
                <div class="flex flex-wrap items-center gap-3">

                    <span class="font-medium">
                        ${escapeHtml(customer.customerName || 'Unbekannter Kunde')}
                    </span>

                    <span class="badge badge-outline badge-sm">
                        ${matchingCount} / ${allCount} Beziehungen
                    </span>

                    <span class="ml-auto break-all font-mono text-xs opacity-50">
                        ${escapeHtml(customer.customerTenantId || '—')}
                    </span>

                </div>
            </summary>

            <div class="collapse-content">

                <p class="mb-3 text-sm opacity-60">
                    ${matchingCount} von ${allCount} Beziehungen angezeigt.
                    Beziehungsnamen für weitere Details aufklappen.
                </p>

                ${relationshipTable(result.matchingRelationships)}

            </div>

        </details>
    `;
        }).join('');
    }

    $('list-customers').innerHTML = results.map((result) => {
        const customer = result.customer;
        const allCount = result.allRelationships.length;
        const matchingCount = result.matchingRelationships.length;

        const activeCount = result.allRelationships.filter(
            (relationship) =>
                normalizeText(relationship.relationshipStatus) === 'active'
        ).length;

        return `
            <details class="rounded-box border border-base-300 bg-base-100">
                <summary class="cursor-pointer p-4">
                    <span class="font-medium">
                        ${escapeHtml(customer.customerName || 'Unbekannter Kunde')}
                    </span>

                    <span class="badge badge-neutral badge-sm ml-2">
                        ${matchingCount} / ${allCount} Beziehungen
                    </span>

                    <span class="badge badge-success badge-outline badge-sm ml-1">
                        ${activeCount} aktiv gesamt
                    </span>
                </summary>

                <div class="space-y-4 border-t border-base-300 p-4">
                    <div>
                        <div class="text-xs opacity-60">Tenant-ID</div>

                        <div class="break-all font-mono text-xs">
                            ${escapeHtml(customer.customerTenantId || '—')}
                        </div>
                    </div>

                    <p class="text-sm opacity-60">
                        Angezeigt: ${matchingCount} von ${allCount} Beziehungen.
                        Beziehungsnamen aufklappen, um IDs und Rollen zu sehen.
                    </p>

                    ${relationshipTable(result.matchingRelationships)}
                </div>
            </details>
        `;
    }).join('');
}


function resetCustomerFilters() {
    $('search-customers').value = '';
    $('search-relationships').value = '';
    $('filter-status').value = '';
    $('filter-auto-extend').value = '';
    $('filter-presence').value = '';
    $('sort-customers').value = 'name-asc';

    renderCustomers();
}


// Kurze Pause beim Tippen, bevor die Liste neu aufgebaut wird.
let customerSearchTimer = null;

function scheduleCustomerRender() {
    clearTimeout(customerSearchTimer);

    customerSearchTimer = setTimeout(() => {
        renderCustomers();
    }, 200);
}


document.addEventListener('DOMContentLoaded', () => {
    $('search-customers').addEventListener('input', scheduleCustomerRender);
    $('search-relationships').addEventListener('input', scheduleCustomerRender);

    const selectIds = [
        'filter-status',
        'filter-auto-extend',
        'filter-presence',
        'sort-customers'
    ];

    for (const id of selectIds) {
        $(id).addEventListener('change', renderCustomers);
    }

    $('reset-customer-filters').addEventListener(
        'click',
        resetCustomerFilters
    );

    initPage(renderCustomers);
});