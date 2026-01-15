import { ReactNode } from "react";

interface TableProps {
  children: ReactNode;
  className?: string;
}

export function Table({ children, className = "" }: TableProps) {
  return (
    <div className={`overflow-x-auto ${className}`}>
      <table className="min-w-full divide-y divide-gray-700">
        {children}
      </table>
    </div>
  );
}

export function TableHead({ children }: { children: ReactNode }) {
  return (
    <thead className="bg-gray-900">
      <tr>{children}</tr>
    </thead>
  );
}

export function TableHeader({ children }: { children: ReactNode }) {
  return (
    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
      {children}
    </th>
  );
}

export function TableBody({ children }: { children: ReactNode }) {
  return <tbody className="bg-gray-800 divide-y divide-gray-700">{children}</tbody>;
}

export function TableRow({ children }: { children: ReactNode }) {
  return <tr className="hover:bg-gray-750">{children}</tr>;
}

export function TableCell({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <td className={`px-6 py-4 whitespace-nowrap text-sm text-gray-300 ${className}`}>
      {children}
    </td>
  );
}
