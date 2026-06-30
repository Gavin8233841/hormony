/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  ...(process.env.NEXT_OUTPUT_MODE === "standalone" ? { output: "standalone" } : {}),
};

export default nextConfig;
