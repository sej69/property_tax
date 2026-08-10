export function explainResidual(model) {
  return `The independent model predicted ${model.predicted_rate.toFixed(2)}%; the observed rate was ${model.actual_rate.toFixed(2)}%. Residual: ${model.residual.toFixed(2)} percentage points.`;
}
