// Gemeinsame Helfer + Datenabruf für alle Seiten

let gdapData = null;

const getElement = (id) => document.getElementById(id);

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
}

function formatDate(value) {
    if (value === null || value === undefined || value === '') {
        return '—';
    }

    let date;

    if (typeof value === 'string' && value.startsWith('/Date(')) {
        // Beispiel: "/Date(1700663158413)/"
        const millisecondsText = value.slice(6, -2);

        const milliseconds = Number(millisecondsText);

        date = new Date(milliseconds);
    } else {
        // Für normale Datumswerte, beispielsweise ISO-Strings.
        date = new Date(value);
    }

    if (isNaN(date.getTime())) {
        return '—';
    }

    return date.toLocaleDateString('de-CH');
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
        // Anzeigename kommt vom Backend (getRoleMapping); Fallback: GUID
        const name = r.roleDisplayName || r.roleDefinitionId || 'unbekannt';
        return `<span class="badge badge-outline badge-sm">${escapeHtml(name)}</span>`;
    }).join(' ');
}

function customerNameByTenant(tenantId) {
    const c = ((gdapData && gdapData.customers) || []).find((x) => x.customerTenantId === tenantId);
    return c ? c.customerName : (tenantId || '—');
}

async function loadGdapData(forceRefresh = false) {
    // 1. Bereits im Speicher dieser Seite vorhanden?
    if (!forceRefresh && gdapData !== null) {
        return gdapData;
    }

    // 2. Bereits durch eine vorherige Seite im Tab gespeichert?
    try {
        const savedData = forceRefresh ? null : sessionStorage.getItem('gdapDataV2');

        if (savedData !== null) {
            gdapData = JSON.parse(savedData);
            return gdapData;
        }
    } catch (error) {
        console.warn('Browser-Cache konnte nicht gelesen werden:', error);
    }

    // 3. Noch keine Daten vorhanden: beim Backend abrufen.
    const res = await fetch('/api/data', { cache: 'no-store' });

    if (!res.ok) {
        const body = await res.json().catch(() => null);

        throw new Error(
            (body && body.error) || ('HTTP ' + res.status)
        );
    }

    gdapData = await res.json();

    // 4. Für nachfolgende Seiten im selben Tab speichern.
    try {
        sessionStorage.setItem(
            'gdapDataV2',
            JSON.stringify(gdapData)
        );
    } catch (error) {
        console.warn('Browser-Cache konnte nicht gespeichert werden:', error);
    }

    return gdapData;
}

// Standard-Initialisierung einer Datenseite:
// lädt /api/data, blendet #loading aus und ruft die Render-Funktion der Seite auf.
async function initPage(render) {
    let loading = false;
    const refreshButton = createPageRefresh(() => load(true));

    async function load(forceRefresh = false) {
        if (loading) return;
        loading = true;
        refreshButton.disabled = true;
        refreshButton.textContent = 'Wird geladen …';
        getElement('error').classList.add('hidden');
        getElement('loading').classList.remove('hidden');
        try {
            await loadGdapData(forceRefresh);
            render();
            getElement('content').classList.remove('hidden');
        } catch (e) {
            getElement('errorText').textContent =
                'Daten konnten nicht geladen werden: ' + e.message +
                ' — Wurde der Server in einer Session mit aktiver Graph-Verbindung (Connect-MgGraph) gestartet?' +
                (gdapData !== null ? ' Angezeigte Daten sind möglicherweise veraltet.' : '');
            getElement('error').classList.remove('hidden');
        } finally {
            getElement('loading').classList.add('hidden');
            refreshButton.disabled = false;
            refreshButton.textContent = 'Refresh';
            loading = false;
        }
    }

    await load();
}
