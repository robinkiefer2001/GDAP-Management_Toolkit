// Gemeinsames Layout: Navbar (oben) + Footer (unten) für alle Seiten.
// Base-Design hier anpassen – gilt automatisch für jede Seite.

const NAV_ITEMS = [
    { href: 'customers.html', label: 'Customers' },
    { href: 'relationships.html', label: 'Relationships' },
    { href: 'build.html', label: 'Build' },
];

function renderLayout() {
    const current = location.pathname.split('/').pop() || 'index.html';

    const header = `
    <div class="navbar bg-base-100 shadow-sm">
        <div class="flex-1">
            <a class="btn btn-ghost text-xl" href="index.html">GDAP Management Toolkit</a>
        </div>
        <div class="flex-none">
            <ul class="menu menu-horizontal px-1 gap-1">
                ${NAV_ITEMS.map((item) => `
                    <li><a class="${item.href === current ? 'menu-active' : ''}" href="${item.href}">${item.label}</a></li>
                `).join('')}
            </ul>
        </div>
    </div>`;

    const footer = `
    <footer class="footer footer-center p-4 opacity-60">
        <p>GDAP Management Toolkit by robinkiefer2001</p>
    </footer>`;

    document.body.insertAdjacentHTML('afterbegin', header);
    document.body.insertAdjacentHTML('beforeend', footer);
}

document.addEventListener('DOMContentLoaded', renderLayout);
