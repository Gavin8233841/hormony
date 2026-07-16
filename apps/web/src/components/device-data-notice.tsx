import { Smartphone } from "lucide-react";

export function DeviceDataNotice({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="card flex items-start gap-3 border-amber-500/30" role="status">
      <Smartphone className="mt-0.5 shrink-0 text-amber-400" size={20} />
      <div>
        <p className="text-sm font-medium text-slate-200">{title}</p>
        <p className="mt-1 text-xs leading-relaxed text-slate-400">{description}</p>
      </div>
    </div>
  );
}
