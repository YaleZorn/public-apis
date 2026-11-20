/** @type {import('next').NextConfig} */
const nextConfig = {
  // Hosting looks for a post-build `dist` directory (legacy Vite default).
  distDir: "dist",
  serverExternalPackages: ["@electric-sql/pglite", "pg", "stripe"],
  async headers() {
    const security = [
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "X-Frame-Options", value: "DENY" },
      { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
      { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
      {
        key: "Content-Security-Policy",
        value: [
          "default-src 'self'",
          "base-uri 'self'",
          "frame-ancestors 'none'",
          "form-action 'self'",
          "img-src 'self' data: https:",
          "font-src 'self' https://fonts.gstatic.com data:",
          "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
          "script-src 'self' 'unsafe-inline'",
          "connect-src 'self'",
          "object-src 'none'",
        ].join("; "),
      },
    ];
    return [
      {
        source: "/:path*",
        headers: security,
      },
    ];
  },
};

export default nextConfig;
