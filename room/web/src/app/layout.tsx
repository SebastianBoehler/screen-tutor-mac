import type { Metadata } from "next";
import "@livekit/components-styles";
import "katex/dist/katex.min.css";
import "./globals.css";

export const metadata: Metadata = {
  title: "Study Room",
  description: "Shared study room with a voice tutor that sees your desks and draws on a shared board.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" data-lk-theme="default">
      <body>{children}</body>
    </html>
  );
}
