/** @type {import('next').NextConfig} */
const nextConfig = {
  // Hosting looks for a post-build `dist` directory (legacy Vite default).
  distDir: "dist",
  serverExternalPackages: ["@electric-sql/pglite", "pg", "stripe"],
  // CSP with per-request nonces is applied in middleware.js (no script-src unsafe-inline).
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
