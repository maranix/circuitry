import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Circuitry',
  description: 'Pure Dart 3.14+ zero-codegen, DAG-based dependency injection.',
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }]],
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Guide', link: '/guide' },
      { text: 'Flutter', link: '/flutter' },
      { text: 'Tooling', link: '/tooling' },
      {
        text: 'pub.dev',
        link: 'https://pub.dev/packages/circuitry',
      },
    ],
    sidebar: [
      {
        text: 'Documentation',
        items: [
          { text: 'Getting Started', link: '/guide' },
          { text: 'Flutter Integration', link: '/flutter' },
          { text: 'DevTools & Analyzer', link: '/tooling' },
          { text: "DOs & Don'ts", link: '/dos-and-donts' },
        ],
      },
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/maranix/circuitry' },
    ],
    search: {
      provider: 'local',
    },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2026 Raman Verma',
    },
  },
})
