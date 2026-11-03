// GDAP Management Toolkit – Frontend-Logik

// Bekannte Entra-Rollen (RoleDefinitionId -> Anzeigename)
const ROLE_NAMES = {
    '62e90394-69f5-4237-9190-012177145e10': 'Global Administrator',
    'f2ef992c-3afb-46b9-b7cf-a126ee74c451': 'Global Reader',
    '729827e3-9c14-49f7-bb1b-9608f156bbb8': 'Helpdesk Administrator',
    'fe930be7-5e62-47db-91af-98c3a49a38b1': 'User Administrator',
    '29232cdf-9323-42fd-ade2-1d097af3e4de': 'Exchange Administrator',
    'f28a1f50-f6e7-4571-818b-6a12f2af6b6c': 'SharePoint Administrator',
    '69091246-20e8-4a56-aa4d-066075b2a7a8': 'Teams Administrator',
    '3a2c62db-5318-420d-8d74-23affee5d9d5': 'Intune Administrator',
    '194ae4cb-b126-40b2-bd5b-6091b380977d': 'Security Administrator',
    '5d6b6bb7-de71-4623-b4af-96380a352509': 'Security Reader',
    '17315797-102d-40b4-93e0-432062caca18': 'Compliance Administrator',
    'b0f54661-2d74-4c50-afa3-1ec803f12efe': 'Billing Administrator',
    'c4e39bd9-1100-46d3-8c65-fb160da0071f': 'Authentication Administrator',
    '7be44c8a-adaf-4e2a-84d6-ab2649e08a13': 'Privileged Authentication Administrator',
    'e8611ab8-c189-46e8-94e1-60213ab1f814': 'Privileged Role Administrator',
    'fdd7a751-b60b-444a-984c-02652fe8fa1c': 'Groups Administrator',
    '966707d0-3269-4727-9be2-8c3a10f19b9d': 'Password Administrator',
    '4a5d8f65-41da-4de4-8968-e035b65339cf': 'Reports Reader',
    '88d8e3e3-8f55-4a1e-953a-9b9898b8876b': 'Directory Readers',
    '11648597-926c-4cf3-9c36-bcebb0ba8dcc': 'Power Platform Administrator'
};

let gdapData = { customers: [], relationships: [] };

const $ = (id) => document.getElementById(id);

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
}

function formatDate(value) {
    if (!value) return '—';
    const d = new Date(value);
    return isNaN(d) ? '—' : d.toLocaleDateString('de-CH');
}

function statusBadge(status) {
    const s = (status || '').toLowerCase();
    let cls = 'badge-warning';
    if (s === 'active') cls = 'badge-success';
    else if (s === 'terminated' || s === 'expired') cls = 'badge-error';
    return `<span class="badge ${cls} badge-sm">${escapeHtml(status || 'unknown')}</span>`;
}

function roleBadges(roles) {
    if (!roles || !roles.length) return '<span class="text-sm opacity-60">keine Rollen</span>';
    return roles.map((r) => {
        const id = r.RoleDefinitionId || r.roleDefinitionId || '';
        const name = ROLE_NAMES[id] || id;
        return `<span class="badge badge-outline badge-sm">${escapeHtml(name)}</span>`;
    }).join(' ');
}

function customerNameByTenant(tenantId) {
    const c = (gdapData.customers || []).find((x) => x.customerTenantId === tenantId);
    return c ? c.customerName : (tenantId || '—');
}

// ---------- Customers-View ----------

function relationshipTable(rels) {
    if (!rels || !rels.length) {
        return '<p class="text-sm opacity-60">Keine GDAP-Beziehungen vorhanden.</p>';
    }
    const rows = rels.map((r) => `
        <tr>
            <td>${escapeHtml(r.relationshipName)}</td>
            <td>${statusBadge(r.relationshipStatus)}</td>
            <td>${r.relationshipAutoExtend ? '<span class="badge badge-info badge-sm">auto</span>' : '—'}</td>
            <td>${formatDate(r.relationshipStartDate)}</td>
            <td>${formatDate(r.relationshipExpirationDate)}</td>
        </tr>`).join('');
    return `
        <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
                <thead><tr><th>Name</th><th>Status</th><th>Auto-Extend</th><th>Start</th><th>Ablauf</th></tr></thead>
                <tbody>${rows}</tbody>
            </table>
        </div>`;
}

function renderCustomers(filter = '') {
    const list = $('list-customers');
    const f = filter.trim().toLowerCase();
    const customers = (gdapData.customers || [])
        .filter((c) => !f || (c.customerName || '').toLowerCase().includes(f))
        .sort((a, b) => (a.customerName || '').localeCompare(b.customerName || ''));

    if (!customers.length) {
        list.innerHTML = '<div class="alert">Keine Kunden gefunden.</div>';
        return;
    }

    list.innerHTML = customers.map((c) => {
        const rels = c.customerGdapRelationships || [];
        return `
        <div class="collapse collapse-arrow bg-base-100 border border-base-300">
            <input type="checkbox">
            <div class="collapse-title flex items-center gap-3 font-medium">
                <span>${escapeHtml(c.customerName)}</span>
                <span class="badge badge-neutral badge-sm">${rels.length} Beziehung${rels.length === 1 ? '' : 'en'}</span>
                <span class="ml-auto mr-2 font-mono text-xs opacity-50">${escapeHtml(c.customerTenantId)}</span>
            </div>
            <div class="collapse-content">
                ${relationshipTable(rels)}
            </div>
        </div>`;
    }).join('');
}

// ---------- Relationships-View ----------

function renderRelationships(filter = '') {
    const list = $('list-relationships');
    const f = filter.trim().toLowerCase();
    const rels = (gdapData.relationships || [])
        .filter((r) => !f
            || (r.relationshipName || '').toLowerCase().includes(f)
            || customerNameByTenant(r.relationshipCustomerId).toLowerCase().includes(f))
        .sort((a, b) => (a.relationshipName || '').localeCompare(b.relationshipName || ''));

    if (!rels.length) {
        list.innerHTML = '<div class="alert">Keine Relationships gefunden.</div>';
        return;
    }

    list.innerHTML = rels.map((r) => {
        const roles = r.relationshipRoles || [];
        return `
        <div class="collapse collapse-arrow bg-base-100 border border-base-300">
            <input type="checkbox">
            <div class="collapse-title flex items-center gap-3 font-medium">
                <span class="truncate">${escapeHtml(r.relationshipName)}</span>
                ${statusBadge(r.relationshipStatus)}
                <span class="ml-auto mr-2 text-xs opacity-50">Ablauf: ${formatDate(r.relationshipExpirationDate)}</span>
            </div>
            <div class="collapse-content space-y-3">
                <div class="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
                    <div><span class="opacity-60">Kunde:</span> ${escapeHtml(customerNameByTenant(r.relationshipCustomerId))}</div>
                    <div><span class="opacity-60">Tenant-ID:</span> <span class="font-mono text-xs">${escapeHtml(r.relationshipCustomerId)}</span></div>
                    <div><span class="opacity-60">Start:</span> ${formatDate(r.relationshipStartDate)}</div>
                    <div><span class="opacity-60">Ablauf:</span> ${formatDate(r.relationshipExpirationDate)}</div>
                    <div><span class="opacity-60">Auto-Extend:</span> ${r.relationshipAutoExtend ? 'aktiviert' : 'deaktiviert'}</div>
                    <div><span class="opacity-60">Rollen:</span> ${roles.length}</div>
                </div>
                <div class="flex flex-wrap gap-1">${roleBadges(roles)}</div>
            </div>
        </div>`;
    }).join('');
}

// ---------- Navigation & Laden ----------

function showView(view) {
    for (const v of ['customers', 'relationships']) {
        $('view-' + v).classList.toggle('hidden', v !== view);
        $('nav-' + v).classList.toggle('menu-active', v === view);
    }
}

async function loadData() {
    try {
        const res = await fetch('/api/data');
        if (!res.ok) {
            const body = await res.json().catch(() => null);
            throw new Error((body && body.error) || ('HTTP ' + res.status));
        }
        gdapData = await res.json();
        $('loading').classList.add('hidden');
        renderCustomers();
        renderRelationships();
        showView('customers');
    } catch (e) {
        $('loading').classList.add('hidden');
        $('error-text').textContent =
            'Daten konnten nicht geladen werden: ' + e.message +
            ' — Wurde der Server in einer Session mit aktiver Graph-Verbindung (Connect-MgGraph) gestartet?';
        $('error').classList.remove('hidden');
    }
}

document.addEventListener('DOMContentLoaded', () => {
    $('search-customers').addEventListener('input', (e) => renderCustomers(e.target.value));
    $('search-relationships').addEventListener('input', (e) => renderRelationships(e.target.value));
    loadData();
});
