/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    appDir: true
  },
  env: {
    NEXTAUTH_URL: process.env.NEXTAUTH_URL || 'https://www.cambodia.com',
  },
};

export default nextConfig;
