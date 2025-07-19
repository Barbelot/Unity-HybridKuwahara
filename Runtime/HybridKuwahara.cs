using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using System;

[Serializable, VolumeComponentMenu("Post-processing/Custom/HybridKuwahara")]
public sealed class HybridKuwahara : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0, 0, 1);

    public ClampedIntParameter radiusSize = new ClampedIntParameter(1, 1, 100);

    public ClampedFloatParameter sharpness = new ClampedFloatParameter(10, 1, 20);

    public ClampedIntParameter overlapSlider = new ClampedIntParameter(1, 1, 5);

    public BoolParameter lineArt = new BoolParameter(false);
    public ClampedFloatParameter lineArtIntensity = new ClampedFloatParameter(1, -100, 100);

    Material m_Material;

    public bool IsActive() => m_Material != null && intensity.value > 0;

    // Do not forget to add this post process in the Custom Post Process Orders list (Project Settings > Graphics > HDRP Global Settings).
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    const string kShaderName = "Hidden/Shader/HybridKuwahara";

    public override void Setup()
    {
        if (Shader.Find(kShaderName) != null)
            m_Material = new Material(Shader.Find(kShaderName));
        else
            Debug.LogError($"Unable to find shader '{kShaderName}'. Post Process Volume HybridKuwahara is unable to load. To fix this, please edit the 'kShaderName' constant in HybridKuwahara.cs or change the name of your custom post process shader.");
    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        if (m_Material == null)
            return;

        m_Material.SetFloat("_Intensity", intensity.value);
        m_Material.SetInt("_KernelSize", radiusSize.value + 1);
        m_Material.SetFloat("_Sharpness", sharpness.value);
        m_Material.SetFloat("_Overlap", Mathf.Pow(2, overlapSlider.value) * 0.1f + 0.01f);
        m_Material.SetFloat("_Scaling", (lineArt.value) ? lineArtIntensity.value : 0);

        m_Material.SetTexture("_MainTex", source);
        HDUtils.DrawFullScreen(cmd, m_Material, destination, shaderPassId: 0);
    }

    public override void Cleanup()
    {
        CoreUtils.Destroy(m_Material);
    }
}
