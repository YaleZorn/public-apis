import { headers } from "next/headers";
import "./globals.css";

export const metadata = {
  title: "Stackpick — pick a public API stack fast",
  description:
    "Search 1600+ curated public APIs, shortlist a stack, export, share, and check endpoint health.",
};

export default async function RootLayout({ children }) {
  const nonce = (await headers()).get("x-nonce") || undefined;
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600;700&family=Source+Sans+3:wght@400;600;700&display=swap"
          rel="stylesheet"
        />
        {nonce ? <meta property="csp-nonce" content={nonce} /> : null}
      </head>
      <body>{children}</body>
    </html>
  );
}
