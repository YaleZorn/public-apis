/** @type {import('next').NextConfig} */
const nextConfig = {
  // Hosting looks for a post-build `dist` directory (legacy Vite default).
  distDir: "dist",
  serverExternalPackages: ["@electric-sql/pglite", "pg"],
};

export default nextConfig;
