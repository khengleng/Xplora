import { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  className?: string;
  title?: string;
}

export function Card({ children, className = "", title }: CardProps) {
  return (
    <div className={`bg-gray-800 rounded-lg border border-gray-700 p-6 ${className}`}>
      {title && (
        <h2 className="text-xl font-semibold text-white mb-4">{title}</h2>
      )}
      {children}
    </div>
  );
}
